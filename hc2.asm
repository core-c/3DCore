


;nog maken:
;Verschillende teken-modus, zoals triangles, quads of multi-point-faces.
;
;nog verbeteren:
;de faces moeten niet sequencieel maar in een loop verwerkt worden.
;misschien wel niet zo snel (ivm. jumps) maar met multi-point-faces
;wel zo makkelijk (of quads).
;


.386p
.model flat,STDCALL
;locals
jumps


SEGMENT DATA USE32 PAGE
ALIGN 32
	; OpenGL entry points
	pNormal3f_Entry		dd ?
	pVertex3f_Entry		dd ?
	pTexCoord2f_Entry	dd ?
ends






.code
SEGMENT CODE USE32 PAGE
ALIGN 32


; ==============================================================================================
;   procedure asmInit(var pTexCoord2f, pNormal3f, pVertex3f: pointer); external;
; ==============================================================================================
    Public asmInit
asmInit proc near
inpTexCoord2f	equ dword ptr [ebp+16]
inpNormal3f	equ dword ptr [ebp+12]
inpVertex3f	equ dword ptr [ebp+8]
	push ebp
	mov ebp,esp

	mov eax,[inpNormal3f]
	mov [pNormal3f_Entry],eax
	mov eax,[inpVertex3f]
	mov [pVertex3f_Entry],eax
	mov eax,[inpTexCoord2f]
	mov [pTexCoord2f_Entry],eax

	pop ebp
	ret 12
asmInit endp







; ==============================================================================================
;   procedure asmDrawTexturedObject(var pObjV,pObjN,pObjF,pObjT: pointer;
;                                   var NrOfFaces: integer); external;
; ==============================================================================================
    Public asmDrawTexturedObject
asmDrawTexturedObject proc near
inObjV	equ dword ptr [ebp+24]			;pointer
inObjN	equ dword ptr [ebp+20]			;pointer
inObjT	equ dword ptr [ebp+16]			;pointer
inObjF	equ dword ptr [ebp+12]			;pointer
inNrOfF	equ dword ptr [ebp+8]			;integer

	push ebp
	mov ebp,esp
	push edx
	push ebx				;loop Face counter   (for F:=0 to inNrOfF)
        push esi
        push edi

	mov ebx,inNrOfF
	nop
nextTFace:



;{== normaal berekenen ==================================}
;{=======================================================}
        mov eax,inObjN
        mov edx,[eax]				;normal[0]
        mov esi,[eax+4]				;normal[1]
        mov edi,[eax+8]				;normal[2]
;{==== normaal counter verhogen voor 3*single=12 bytes ==}
        add eax,12
        mov inObjN,eax
;{==== OpenGL aanroepen om normal te verwerken ==========}
;{==== glNormal3f( edx, esi, edi ); =====================}
        push edi
        push esi
        push edx
        call pNormal3f_Entry




;{==== lees 1e vert van de te tekenen face of zijde =====}
;{=======================================================}
        mov ecx,inObjF				;ecx = pointer naar face[qFF]
        xor eax,eax
        mov ax,word ptr [ecx]
;        test ax,08000h				;test of zijde getekend moet worden
;        setne qb0				;boolean van zijde tekenen opslaan
        and eax,00007FFFh			;hoogste bit wissen van vert#
;{==== Texture coordinaten verwerken ====================}
;{==== voor elke vert zijn er 2 TexCoord2f, dus 8 bytes =}
	push eax
	shl eax,3
	add eax,inObjT
	mov esi,[eax]				;OpenGL call
	mov edi,[eax+4]
	push edi
	push esi
	call pTexCoord2f_Entry
	pop eax
;{==== Vertex coordinaten verwerken =====================}
;{==== 1 AffineFloatVector size = 3*single = 12 bytes ===}
        xor edx,edx
        mov dx,ax
        shl eax,2
        shl edx,3
        add eax,edx
        add eax,inObjV
;{==== OpenGL aanroepen om vertex te verwerken ==========}
;{==== glVertex3f( edx, esi, edi ); =====================}
        mov edx,[eax]
        mov esi,[eax+4]
        mov edi,[eax+8]
        push edi
        push esi
        push edx
        call pVertex3f_Entry





;{==== lees 2e vert van de te tekenen face of zijde =====}
;{=======================================================}
        mov ecx,inObjF
        xor eax,eax
        mov ax,word ptr [ecx+2]
;        test ax,08000h
;        setne qb1
        and eax,00007FFFh
;{==== Texture coordinaten ==============================}
	push eax
	shl eax,3
	add eax,inObjT
	mov esi,[eax]				;OpenGL call
	mov edi,[eax+4]
	push edi
	push esi
	call pTexCoord2f_Entry
	pop eax
;{==== Vertex coordinaten ===============================}
        xor edx,edx
        mov dx,ax
        shl eax,2
        shl edx,3
        add eax,edx
        add eax,inObjV
        mov edx,[eax]				;OpenGL call
        mov esi,[eax+4]
        mov edi,[eax+8]
        push edi
        push esi
        push edx
        call pVertex3f_Entry





;{==== lees 3e vert van de te tekenen face of zijde =====}
;{=======================================================}
        mov ecx,inObjF
        xor eax,eax
        mov ax,word ptr [ecx+4]
;        test ax,08000h
;        setne qb2
        and eax,00007FFFh
;{==== Texture coordinaten ==============================}
	push eax
	shl eax,3
	add eax,inObjT
	mov esi,[eax]				;OpenGL call
	mov edi,[eax+4]
	push edi
	push esi
	call pTexCoord2f_Entry
	pop eax
;{==== Vertex coordinaten ===============================}
        xor edx,edx
        mov dx,ax
        shl eax,2
        shl edx,3
        add eax,edx
        add eax,inObjV
        mov edx,[eax]				;OpenGL call
        mov esi,[eax+4]
        mov edi,[eax+8]
        push edi
        push esi
        push edx
        call pVertex3f_Entry





;{==== face counter verhogen voor 3 words=6 bytes =======}
;{=======================================================}
        mov ecx,inObjF
        add ecx,6
        mov inObjF,ecx
;	add inObjF,6

;{==== de main Face-loop ================================}
	dec ebx
	cmp ebx,0
	jne nextTFace

        pop edi
        pop esi
	pop ebx
	pop edx
	pop ebp
	ret 20
asmDrawTexturedObject endp













; ==============================================================================================
;   procedure asmDrawObject(var pObjV,pObjN,pObjF: pointer;
;                           var NrOfFaces: integer); external;
; ==============================================================================================
    Public asmDrawObject
asmDrawObject proc near
inObjV	equ dword ptr [ebp+20]			;pointer
inObjN	equ dword ptr [ebp+16]			;pointer
inObjF	equ dword ptr [ebp+12]			;pointer
inNrOfF	equ dword ptr [ebp+8]			;integer
	push ebp
	mov ebp,esp
	push edx
	push ebx				;loop F   for F:=0 to inNrOfF
        push esi
        push edi


	mov ebx,inNrOfF
	nop
nextFace:



;    {== normaal berekenen =============================}
;    {==================================================}
        mov eax,inObjN
        mov edx,[eax]
        mov esi,[eax+4]
        mov edi,[eax+8]
;    {== normaal counter verhogen voor 3*single=12 bytes}
        add eax,12
        mov inObjN,eax
;    {== OpenGL aanroepen om normal te verwerken =======}
;      glNormal3f( edx, esi, ecx );
        push edi
        push esi
        push edx
        call pNormal3f_Entry




;    {lees 1e vert van de te tekenen face of zijde =======}
;    {====================================================}
        mov ecx,inObjF				;{ecx = pointer naar face[qFF]}
        xor eax,eax
        mov ax,word ptr [ecx]
;        test ax,08000h    {test of zijde getekend moet worden}
;        setne qb0         {boolean van zijde tekenen opslaan}
        and eax,00007FFFh			;{hoogste bit wissen van vert#}
;
;        {cx = vert index in face-array}
;        {cx*12, 1 AffineFloatVector size}
        xor edx,edx
        mov dx,ax
        shl eax,2
        shl edx,3
        add eax,edx
        add eax,inObjV				;{vert-adres in eax}
;
        mov edx,[eax]				;OpenGL call
        mov esi,[eax+4]
        mov edi,[eax+8]
        push edi
        push esi
        push edx
        call pVertex3f_Entry





;    {lees 2e vert van de te tekenen face of zijde =======}
;    {====================================================}
        mov ecx,inObjF				;{ecx = pointer naar face[qFF]}
        xor eax,eax
        mov ax,word ptr [ecx+2]
;        test ax,08000h
;        setne qb1
        and eax,00007FFFh
	;
;        {cx*12, 1 AffineFloatVector size}
        xor edx,edx
        mov dx,ax
        shl eax,2
        shl edx,3
        add eax,edx
;
        add eax,inObjV
;
        mov edx,[eax]
        mov esi,[eax+4]
        mov edi,[eax+8]
        push edi
        push esi
        push edx
        call pVertex3f_Entry





;    {lees 3e vert van de te tekenen face of zijde =======}
;    {====================================================}
        mov ecx,inObjF				;{ecx = pointer naar face[qFF]}
        xor eax,eax
        mov ax,word ptr [ecx+4]
;        test ax,08000h
;        setne qb2
        and eax,00007FFFh
	;
;        {cx*12, 1 AffineFloatVector size}
        xor edx,edx
        mov dx,ax
        shl eax,2
        shl edx,3
        add eax,edx
;
        add eax,inObjV
;
        mov edx,[eax]
        mov esi,[eax+4]
        mov edi,[eax+8]
        push edi
        push esi
        push edx
        call pVertex3f_Entry





;    {== face counter verhogen voor 3 words=6 bytes}
        mov ecx,inObjF
        add ecx,6
        mov inObjF,ecx
;	add inObjF,6

; de Face-loop
	dec ebx
	cmp ebx,0
	jne nextFace



        pop edi
        pop esi
	pop ebx
	pop edx
	pop ebp
	ret 16
asmDrawObject endp







ends
    End

