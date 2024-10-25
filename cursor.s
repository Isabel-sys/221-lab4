.section .data 
usg : .asciz "Usage: cursor [-h|(tail,letter)*]\n\ttail\tleave a tail\n\tletter\tswitch cntrl scheme to {i,j,k,m}\n\t-h\tthis message\n"

tailc : .asciz "tail"
helpc : .asciz "-h"
lettc : .asciz "letter"

flags: .long 0 
hdr : .asciz "Use %s to move cursor (%s).\n0 exits.\nAny other key will change cursor.\n"

pad_n : .asciz "keypad"
pad_l : .asciz "keyboard"

ctr_n : .asciz "8,4,2,6"
ctr_l : .asciz "i,j,k,m"

dir_fmt : .asciz "Direction: %d"
let_fmt : .asciz "Letter: %d"

# ======= Input Selection Encoding ========== 
# [2,4,6,8] = 0xTTFFSSEE (T = '2', F = '4', S = '6', E = '8')
# [m,j,k,i] = 0xMMJJKKII 
# Encoded backwards to account for little-endian 
.equ num_move , 0x38363432 # { 8 , 6 , 4 , 2}
.equ let_move , 0x696B6A6D # { i , k , j , m}

# ====== Argument Flags ====== 
.equ TAIL , 0x01 
.equ LETT , 0x02
# ============================
JT_move: 
  .quad case_two 
  .quad case_four 
  .quad case_six 
  .quad case_eight 
  .quad default

.section .text
  .globl main 

# === set_flag === 
# @brief Helper function which returns either the given flag, or 0 
# 
# @param char* str  - Potential verb          (RDI)
# @param char* vrb  - verb to compare against (RSI)
# @param int   mask - mask to apply to flags  (EDX)
# 
# @return mask or  0
set_flag: 
  push %rbp 
  push %rbx 

  movq $0   , %rbp 
  movq %rdx , %rbx 

  call strcmp 
  testq %rax , %rax 
  cmovz %rbx , %rbp  

  movq  %rbp , %rax 

  pop %rbx 
  pop %rbp 
  ret 
  


# === process_args === 
# @brief processes command line arguments 
# 
# @param int argc    - Argument Count  (EDI)
# @param char** argv - Argument Vector (RSI)
# @param int* flags   - Whether or not to add a tail (RDX)
# 
# @return int 
process_args: 
  push %rbp 
  push %rbx 
  push %r12 
  push %r13

  xorq %rax , %rax

  cmpl $2 , %edi 
  jb pa_end 


  movl %edi , %ebx # 2 -> 1, etc 
  decl %ebx
  movq %rsi , %r12 
  movq %rdx , %r13 
  xorq %rbp , %rbp 



pa_loop: 
  cmpq %rbx , %rbp 
  je pa_end

  movq 8(%r12,%rbp,8) , %rdi  
  leaq tailc(%rip)   , %rsi 
  movl $TAIL         , %edx 
  call set_flag 
  orl  %eax , (%r13)
  test %eax , %eax 
  jnz  pa_iter  
  # flag /= 0 => next token 


  movq 8(%r12,%rbp,8) , %rdi 
  leaq lettc(%rip)   , %rsi 
  movl $LETT         , %edx 
  call set_flag
  orl  %eax , (%r13)
  test %eax , %eax 
  jnz  pa_iter

  movq 8(%r12,%rbp,8) , %rdi
  leaq helpc(%rip)    , %rsi 
  call strcmp
  testq %rax , %rax 
  jz pa_help
  # -h =>  print help + exit 

pa_iter: 
  incq %rbp 
  jmp pa_loop
  jmp 1f

pa_help: 
  leaq usg(%rip) , %rdi 
  call printf 
  movq $1 , %rax 
  jmp 2f 

pa_end:
1: 
  movq $0 , %rax 
2: 
  pop %r13 
  pop %r12 
  pop %rbx
  pop %rbp
  ret 

# === initialize === 
# @brief initializes context for execution
# 
# @return void 
initialize: 
  call initscr 
  call clear 
  movl $0 , %edi 
  call curs_set 
  call cbreak 
  call noecho 
  ret 

# === teardown === 
# @brief closes the context before restoring original state 
# 0xIIJJKKMM
# @return void 
teardown: 
  call endwin
  
# === header === 
# @brief prints the header during runtime 
# 
# @param flags - %edi 
# @return void 
header: 
  andl $LETT , %edi 
  cmpl $LETT , %edi 
  jne 2f 
1: 
  leaq pad_l(%rip) , %rsi 
  leaq ctr_l(%rip) , %rdx 
  jmp 3f 
2: 
  leaq pad_n(%rip) , %rsi 
  leaq ctr_l(%rip) , %rdx
3:
  leaq hdr(%rip) , %rdi 
  call printw 
  ret 

# === lookup jmp ==== 
# @brief sequential search through a predefined table of 
#        values where the idx of the value is equivalent 
#        to the offset of the branches address in the JT 
# 
# @param char *lookup_table -  {RDI}
# @param int   key          -  {ESI}
# 
# @return long 
lookup_jmp: 
  # if we can't find the key in our list we know that  
  # we have to jump to the default case 
  movq $4 , %rax
  xorq %rcx , %rcx 
1: 
  cmpq $4 , %rcx 
  je 3f 
  cmpb (%rdi,%rcx) , %sil 
  je 2f 
  incq %rcx 
  jmp 1b 
2: 
  # found case => rax = case 
  movq %rcx , %rax 
3: 
  ret

# === wraparound === 
# @brief if x > b, x = a if x < a,  x = b 
# 
# @param int a - lower bound (EDI)
# @param int b - upper bound (ESI)
# @param int x - value to bound (EDX)
# @return int 
wraparound: 
  cmpl %edi , %edx  
  jge 1f 
  movl %esi , %edx
  decl %edx
  jmp 2f
1: 
  cmpl %esi , %edx 
  jl 2f 
  movl %edi , %edx 
2: 
  movl %edx, %eax
  ret 
# === process === 
# @brief  process keypresses 
# @param  int tail (EDI)
# @param 
process: 
  push %rbp 
  movq %rsp , %rbp 
  subq $40 , %rsp 

  # -4(%rbp)  -> int  c 
  # -8(%rbp)  -> int  row 
  # -12(%rbp) -> int  col  
  # -16(%rbp) -> int  prev_c 
  # -17(%rbp) -> char point 
  # -24(%rbp) -> direction change 
  # -28(%rbp) -> cursor change 
  # -32(%rbp) -> lookup table 


  movl $0 , -24(%rbp)
  movl $0 , -28(%rbp)

  movl %edi , %ebx # <- preserve tail in EBX

  movl $5 ,  -8(%rbp)
  movl $5 , -12(%rbp)

  # (LETT & flags) == LETT => letter control scheme 
  movl $num_move, -32(%rbp) 
  andl $LETT , %edi 
  cmpl $LETT , %edi 
  jne 1f 
  movl $let_move , -32(%rbp)
1: 


  movq stdscr@GOTPCREL(%rip) , %rax 
  movq (%rax)    , %rdi 
  movl  -8(%rbp) , %esi 
  movl -12(%rbp) , %edx 
  call mvwinch 
  movl %eax , -16(%rbp) #  save the character that previously filled screen[row][col] 


  movb $'+' , -17(%rbp)

  movl  -8(%rbp) , %edi 
  movl -12(%rbp) , %esi 
  movb -17(%rbp) , %dl 
  call mvaddch # <- prints '+' to (5,5)

p_start: 

  # print number of changes to direction 
  movl $3            , %edi 
  movl $0            , %esi 
  leaq dir_fmt(%rip) , %rdx 
  movl -24(%rbp)     , %ecx
  call mvprintw 

  # print number of changes to cursor 
  movl $4            , %edi 
  movl $0            , %esi 
  leaq let_fmt(%rip) , %rdx 
  movl -28(%rbp)     , %ecx
  call mvprintw

  call getch 
  cmpb $'0' , %al 
  je p_end 

  movl %eax , -4(%rbp)

  # (TAIL & flags) == TAIL => 'render' tail (do not draw over c in last position)
  movl %ebx  , %eax 
  andl $TAIL , %eax 
  cmpl $TAIL , %eax 
  je 1f # <- if tail then skip 

  movl -8(%rbp)  , %edi 
  movl -12(%rbp) , %esi 
  movl -16(%rbp) , %edx 
  call mvaddch 
1: 

  
  leaq -32(%rbp) , %rdi 
  movl -4(%rbp)  , %esi
  call lookup_jmp

  movq %rax , %rcx

  # rcx /= 4 => -24(%rbp) += 1 
  cmpq $4 , %rcx 
  je 2f 

  addl $1 , -24(%rbp)

2: 


  leaq JT_move(%rip) , %rax 
  jmp *(%rax,%rcx,8)

# = case ('2'/'m') = 
case_two: 
  addl $1, -8(%rbp)
  jmp end 

# = case ('4'/'j') =  
case_four: 
  subl $1 , -12(%rbp)
  jmp end 
# = case ('6'/k) = 
case_six: 
  addl $1 , -12(%rbp)
  jmp end 
# = case ('8'/'i') = 
case_eight: 
  subl $1 , -8(%rbp) 
  jmp end 
default: 
  movl -4(%rbp) , %eax 
  movb %al , -17(%rbp)
  addl $1 , -28(%rbp)
end: 

  movq LINES@GOTPCREL(%rip) , %rax 
  movl $0       , %edi 
  movl (%rax)   , %esi 
  movl -8(%rbp) , %edx 
  call wraparound
  movl %eax , -8(%rbp)

  movq COLS@GOTPCREL(%rip) , %rax 
  movl $0                  , %edi 
  movl (%rax)              , %esi 
  movl -12(%rbp)            , %edx
  call wraparound
  movl %eax , -12(%rbp)



  # save the character at the current position before overwriting 
  movq stdscr@GOTPCREL(%rip) , %rax 
  movq (%rax)    , %rdi 
  movl -8(%rbp)  , %esi 
  movl -12(%rbp) , %edx 
  call mvwinch
  movl %eax , -16(%rbp)

  # overwrite current position with c
  movl -8(%rbp)  , %edi 
  movl -12(%rbp) , %esi 
  movb -17(%rbp) , %dl 
  call mvaddch

  jmp p_start
p_end: 

  addq $40 , %rsp 
  pop %rbp
  ret 


main: 
  movl $0 , flags
  leaq flags(%rip) , %rdx
  call process_args
  testq %rax , %rax 

  jz 1f 

  movq %rax , %rdi 
  movq $60  , %rax 
  syscall

1: 

  call initialize
  movl flags, %edi
  call header

  movl flags , %edi 
  call process
  
  call teardown

  movq $60 , %rax 
  movq $0  , %rdi 
  syscall
