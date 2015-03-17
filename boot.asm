       .80386
       

BOOTSEG	equ 0x07c0
SYSSEG	equ 0x1000
SYSLEN	equ 17

;先使用bios的int 0x13中断功能读取磁盘
;将head程序读到0x10000处
;然后移动head程序到0x0000处
;为什么不直接读取0x0000处
;因为bios的中断向量表存放在0x7c00之前的地方,
;如果直接将head程序读取到0x0000处会将其覆盖,产生错误
[BITS 16]
[ORG 0x0000]

_start:
	jmp 0x7c0:go	;使用跳转设置cs寄存器
go:	mov ax,cs	
	mov ds,ax
	mov ss,ax
	mov sp,0x400	;设置栈顶指针

load_system:
	mov dx,0x0000	;dh=磁头号 dl=驱动号 
	mov cx,0x0002	;ch=磁道号低8位 cl=位6,7磁道号高2位，0-5其实扇区号
	mov ax,SYSSEG	;es:bx=读入的缓冲区
	mov es,ax
	xor bx,bx
	mov ax,0x200+SYSLEN	;ah=读取扇区功能号 al=需要读取扇区数
	int 0x13	;使用中断读取磁盘
	jnc ok_load
die:	jmp die

ok_load:
	cli
	mov ax,SYSSEG	
	mov ds,ax
	xor ax,ax	
	mov es,ax	;es=0x0000
	mov cx,0x1000	;mov 4kb
	sub si,si	;清零si,di
	sub di,di
	rep movsw	;movsw 每次移动一个字节
			;将ds:si(0x1000:0000)指向的数据
			;移动到es:di(0x0000:0000)指向地址处

	;load IDT GDT
	mov ax,BOOTSEG
	mov ds,ax
	lidt [idt_48]	;加载临时idt
	lgdt [gdt_48]	;加载临时gdt

	

	;设置cr0寄存器开启保护模式
	mov eax,cr0
	or eax,1
	mov cr0,eax

	;紧接着一个跳转
	jmp 0x08:0x0	;0x80为代码段描述符,它指向0x0000:0x0

;gdt表
;选择符的计算 偏移+属性
;gdt中选择符属性都为0,选择符即为偏移地址
;基址0x00000
;段限长2KB*4KB=8MB
gdt:
	dw 0,0,0,0			;第0项空描述符,不用
	dw 0x07ff,0x0000,0x9a00,0x00c0	;内核代码段描述符,选择符0x08
	dw 0x07ff,0x0000,0x9200,0x00c0	;内核数据段描述符,选择符0x10

idt_48: dw 0
	dw 0,0
gdt_48:	dw 0x7ff		;段限长
	dw 0x7c00+gdt,0		;0x7c00+gdt是gdt表在内存中的位置
