.386
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc
extern printf: proc

includelib canvas.lib
extern BeginDrawing: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data
;aici declaram date
window_title DB "MAZE OF ROOMS",0
matrice dd 16 dup(0)
area_width EQU 640
area_height EQU 480
area DD 0
i dd 0
j dd 0
x dd 0
y dd 0

pasi dd 10

ok1 dd 1
ok0 dd 0


; legend DB '2','1','1','1'
		; DB '0','0','0','1'
		; DB '0','1','9','0'
		; DB '1','0','1','0'

counter DD 0 ; numara evenimentele de tip timer

;matrice dd 16 dup(0) ; matrice care va retine valori
x0 dd 120 ;coordonata X a punctului de unde incepe chenarul sa fie desenat
y0 dd 95 ;coordonata Y a punctului de unde incepe chenarul sa fie desenat
lungime_matrice equ 4
inaltime_matrice equ 4

start_cell db "S-a apasat in caseta start",13,10,0

;casutele pe care le vom folosi dupa

xC1 dd 10
yC1 dd 10

xC2 dd 110
yC2 dd 110

game_over dd 0
you_win dd 0


;dimensiune patrat din chenar
celula_width equ 80 
celula_height equ 80
culoare_simbol dd 0

arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20

const equ 80

symbol_width EQU 10
symbol_height EQU 20
spatiu_width equ 65
spatiu_height equ 65
semn_height equ 50			;dimensiunea simbolului
semn_width equ 50			;dimensiunea simbolului

include digits.inc
include letters.inc
include legenda.inc

.code
; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
make_text proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	cmp eax, 'A'
	jl make_digit
	cmp eax, 'Z'
	jg make_digit
	sub eax, 'A'
	lea esi, letters
	jmp draw_text
make_digit:
	cmp eax, '0'
	jl make_space
	cmp eax, '9'
	jg make_space
	sub eax, '0'
	lea esi, digits
	jmp draw_text
make_space:	
	mov eax, 26 ; de la 0 pana la 25 sunt litere, 26 e space
	
draw_text:
	mov ebx, symbol_width
	mul ebx
	mov ebx, symbol_height
	mul ebx
	add esi, eax
	mov ecx, symbol_height
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_width
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_alb
	mov dword ptr [edi], 0
	jmp simbol_pixel_next
simbol_pixel_alb:
	mov dword ptr [edi], 0FFFFFFh
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_text endp

; un macro ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 16
endm

draw_vertical_line_macro macro drawArea, x, y, len
LOCAL vf, final
	push eax
	push ecx
	push ebx
	
	mov eax, 0
	mov eax, x
	mov ebx, 640
	mul ebx
	add eax, y
	shl eax, 2
	mov ecx, 0
vf:
	add eax, 2559
	mov EBX, drawArea
	add ebx, ecx
	mov dword ptr [ebx+eax], 000000h
	inc ecx
	inc ecx
	cmp ecx, len
	je final
	loop vf
final:
	pop ebx
	pop ecx
	pop eax
endm

draw_horizontal_line_macro macro drawArea, x, y, len
LOCAL vf, final
	push eax
	push ecx
	push ebx
	
	mov eax, 0
	mov eax, x
	mov ebx, 640
	mul ebx
	add eax, y
	shl eax, 2
	mov ecx, 0
vf:
	mov EBX, drawArea
	add ebx, ecx
	mov dword ptr [ebx+eax], 000000h
	inc ecx
	inc ecx
	cmp ecx, len
	je final
	loop vf
final:
	pop ebx
	pop ecx
	pop eax
endm

verificare_casuta macro x,y,mesaj,ok
local afara,generare_random,verif_pasi
	pusha 
	mov eax,[ebp+arg2] ;avem x
	mov ebx,[ebp+arg3] ;avem y
	
	;x2=x1+celula_width
	;y2=y1+celula_height
	
	mov ecx,x
	cmp eax,ecx
	jl afara

	add ecx,celula_width
	cmp eax,ecx
	jg afara
	
	mov ecx,y
	cmp ebx,ecx
	jl afara

	add ecx,celula_height
	cmp ebx,ecx
	jg afara
	
	push offset mesaj
	call printf
	add esp,4
	
	;valorile pentru casutele urmatoare
	cmp ok,0
	jne verif_pasi

	
	call end_game
	mov eax,1
	mov game_over,eax
	jmp afara
	
	verif_pasi:
	
	mov eax,pasi
	dec eax
	mov pasi,eax
	cmp eax,0
	jne generare_random ;continuam jocul
	
	call end_game
	mov eax,1
	mov you_win,eax
	jmp afara
	
	generare_random:
	
	mov eax,0
	mov game_over,eax
	mov you_win,eax
	
	call random
	;add esi,30
	;mov xC1,esi

	;mov esi,x2
	;add esi,30
	;mov xC2, esi
	
	afara:
	popa
	
endm

random proc
	
	pusha
	add eax,ebx
	add eax,ecx
	add eax,edx
	add eax,esi
	add eax,edi
	and eax,03h
	mov ebx,const
	mul ebx
	add eax,110 ;ca sa fie afisare pe mijloc
	mov yC1, eax
	
	add eax,ebx
	add eax,ecx
	add eax,edx
	add eax,esi
	add eax,edi
	and eax,03h
	mov ebx,const
	mul ebx
	add eax,110 ;ca sa fie afisare pe mijloc
	mov xC1, eax
	
	repeta:
	
	add eax,ebx
	add eax,ecx
	add eax,edx
	add eax,esi
	add eax,edi
	and eax,03h
	mov ebx,const
	mul ebx
	add eax,110 ;ca sa fie afisare pe mijloc
	mov yC2, eax
	
	add eax,ebx
	add eax,ecx
	add eax,edx
	add eax,esi
	add eax,edi
	and eax,03h
	mov ebx,const
	mul ebx
	add eax,110 ;ca sa fie afisare pe mijloc
	mov xC2, eax
	
	mov eax,xC1
	mov ebx,xC2
	mov ecx,yC2
	mov edx,yC1
	
	cmp eax,ebx
	jne afara
	cmp ecx,edx
	jne afara
	
	jmp repeta
	
	afara:
	popa
	ret 
	
random endp

end_game proc
	pusha
	
	mov eax,110
	mov xC2,eax
	mov yC2,eax
	
	mov eax,10
	mov xC1,eax
	mov yC1,eax
	
	mov pasi,eax ;punem din nou numarul de 10 pasi
	
	popa
	ret

end_game endp

alegere_casuta proc
	pusha
	;casuta start
	verificare_casuta xC1,yC1,start_cell,ok0
	verificare_casuta xC2,yC2,start_cell,ok1
	
	popa
	
	
	
	;verificare_casuta 160,160 ;casuta 0
	; verificare_casuta 320,80 ;casuta 1
	; verificare_casuta 80,240 ;casuta 0 - PERICOL-END GAME
	; verificare_casuta 240,320 ;casuta 1
	; verificare_casuta 240,160 ;casuta 0
	; verificare_casuta 160,80 ;casuta 1
	; verificare_casuta 320,320 ;casuta 0
	; verificare_casuta 240,240 ;casuta 1 _FINAL

alegere_casuta endp

; functia de desenare - se apeleaza la fiecare click
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click)
; arg2 - x
; arg3 - ys
draw proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1]
	cmp eax, 1
	jz evt_click
	cmp eax, 2
	jz evt_timer ; nu s-a efectuat click pe nimic
	
	
	;mai jos e codul care intializeaza fereastra cu pixeli albi
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	;push 255
	push 0415575h
	push area
	call memset
	add esp, 12
	
	; ;;PARCURGERE SI AFISARE MATRICE
	; ;pentru indecsi
	; mov ebx,0 ;ebx e 0
	; ;incepem parcurgerea
	; bucla_i:
		; ;instructiuni
		; mov edx,0 ; edx e 0
		; bucla_j:
			; ;instructiuni
			
			; ;calculam x=x0+j*sw
			; mov eax,edx; punem j in eax
			; push edx
			; mov esi, symbol_width
			; add esi, spatiu_width
			; mul esi
			; add eax,x0
			; mov esi, eax ; avem x in registrul esi
			
			; ;calculam y=y0+i*symbol_height
			; mov eax,ebx; punem i in eax
			; mov edi, symbol_height
			; add edi, spatiu_height
			; mul edi
			; add eax,y0
			
			; mov edi, eax; avem y in registrul edi
			
			; ;calculam i*c+j
			; mov eax, ebx
			; mov edx,lungime_matrice
			; mul edx ;se calculeaza i*c si rezultatul se afla in eax
			; pop edx
			; add eax, edx ;am obtinut i*c+j
			; mov ecx,0
			; mov cl,legend[eax]
			; ;add cl,'0'
			; make_text_macro ecx, area, esi,edi
			
			
			; inc edx
			; cmp edx, lungime_matrice
			; jl bucla_j
		; inc ebx
		; cmp ebx, inaltime_matrice
		; jl bucla_i
	
		
		
	jmp afisare_litere
	
evt_click:
	mov edi, area
	mov ecx, area_height
	mov ebx, [ebp+arg3]
	and ebx, 7
	inc ebx
	call alegere_casuta
	
evt_timer:
	inc counter
	
afisare_litere:
	;afisam valoarea counter-ului curent (sute, zeci si unitati)
	mov ebx, 10
	mov eax, counter
	;cifra unitatilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 30, 10
	;cifra zecilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 20, 10
	;cifra sutelor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 10, 10
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	make_text_macro 'M', area, 150, 20
	make_text_macro 'A', area, 160, 20
	make_text_macro 'Z', area, 170, 20
	make_text_macro 'E', area, 180, 20
	
	make_text_macro 'O', area, 210, 20
	make_text_macro 'F', area, 220, 20
	
	make_text_macro 'R', area, 250, 20
	make_text_macro 'O', area, 260, 20
	make_text_macro 'O', area, 270, 20
	make_text_macro 'M', area, 280, 20
	make_text_macro 'S', area, 290, 20
	
	; make_text_macro 'R', area, 480, 220
	; make_text_macro 'E', area, 490, 220
	; make_text_macro 'S', area, 500, 220
	; make_text_macro 'T', area, 510, 220
	; make_text_macro 'A', area, 520, 220
	; make_text_macro 'R', area, 530, 220
	; make_text_macro 'T', area, 540, 220
	
	
	; ;CHENAR RESTART
	; draw_horizontal_line_macro  area, 220, 475, 300
	; draw_horizontal_line_macro  area, 240, 475, 300
	; draw_vertical_line_macro area, 220, 475, 20
	;draw_vertical_line_macro area, 220, 550, 20
	
	;CHENAR MARE
	draw_horizontal_line_macro  area, 80, 80, 1300
	draw_horizontal_line_macro  area, 400, 80, 1300
	draw_horizontal_line_macro  area, 160, 80, 1300
	draw_horizontal_line_macro  area, 240, 80, 1300
	draw_horizontal_line_macro  area, 320, 80, 1300
	draw_vertical_line_macro area, 80, 80, 320
	draw_vertical_line_macro area, 80, 160, 320
	draw_vertical_line_macro area, 80, 240, 320
	draw_vertical_line_macro area, 80, 320, 320
	draw_vertical_line_macro area, 80, 405, 320
	
	make_text_macro "X",area,xC1,yC1 ;pentru casuta gresita
	make_text_macro "X",area, xC2,yC2 ;pentru casuta corecta
	
	cmp game_over,1
	jne nu_game_over
	
	make_text_macro 'G', area, 250, 50
	make_text_macro 'A', area, 260, 50
	make_text_macro 'M', area, 270, 50
	make_text_macro 'E', area, 280, 50
	make_text_macro 'O', area, 300, 50
	make_text_macro 'V', area, 310, 50
	make_text_macro 'E', area, 320, 50
	make_text_macro 'R', area, 330, 50
	
	
	
	
	nu_game_over:
	cmp you_win,1
	jne final_draw
	
	make_text_macro 'Y', area, 200, 50
	make_text_macro 'O', area, 210, 50
	make_text_macro 'U', area, 220, 50
	
	make_text_macro 'W', area, 250, 50
	make_text_macro 'I', area, 260, 50
	make_text_macro 'N', area, 270, 50

	
	

final_draw:
	popa
	mov esp, ebp
	pop ebp
	ret
draw endp



start:
	;alocam memorie pentru zona de desenat
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov area, eax
	;apelam functia de desenare a ferestrei
	; typedef void (*DrawFunc)(int evt, int x, int y);
	; void __cdecl BeginDrawing(const char *title, int width, int height, unsigned int *area, DrawFunc draw);
	push offset draw
	push area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20
	
	;terminarea programului
	push 0
	call exit
end start
