;
; LAB2.asm
;
; Created: 2/11/2026 4:06:26 PM
; Author : obreg
;

// Encabezado (Definición de Registros, Variables y Constantes)
.include "M328PDEF.inc"     // Include definitions specific to ATMega328P
.dseg
.org    SRAM_START
//variable_name:     .byte   1   // Memory alocation for variable_name:     .byte   (byte size)

.cseg
.org 0x0000
 /****************************************/
// Configuración de la pila
LDI     R16, LOW(RAMEND)
OUT     SPL, R16
LDI     R16, HIGH(RAMEND)
OUT     SPH, R16
/****************************************/
// Configuracion MCU
SETUP:
    // Hablitar el cambio de prescaler y colocar el nuevo valor, para pazar de 16 MHz a 1 MHz el reloj
	LDI R16, (1 << CLKPCE) // se puede poner como 0b10000000
	STS	CLKPR, R16
	LDI	R16, (1 << CLKPS2) // se puede poner como 0b00000100, para colocar un prescaler de 16
	STS CLKPR, R16

	//Inicializamos el timer
	LDI R16, (1 << CS01) | (1 << CS00) //Configuramos el prescaler de 64, equivalente a 0b00000011
	OUT	TCCR0B, R16
	LDI R16, 100  // Cargamos el valor inicial del timer0 en R16
	OUT TCNT0, R16

	// Configurar los pines de salida de los 4 LEDs del contador y el LED de alarma
	// LEDs del contador
	SBI DDRC, PC0
	SBI DDRC, PC1
	SBI DDRC, PC2
	SBI DDRC, PC3
	// LED de alarma
	SBI DDRC, PC4

	// Deshabilitamos la comunicación UART de los pines D0 y D1
	LDI R16, 0x00
	STS UCSR0B, R16

	// Configuración de los pines D0 a D7 como salidas para los LEDs del display de 7 segmentos
	SBI DDRD, PD0
	SBI DDRD, PD1
	SBI DDRD, PD2
	SBI DDRD, PD3
	SBI DDRD, PD4
	SBI DDRD, PD5
	SBI DDRD, PD6

	// Configuramos los pines de entrada de los botones de aumento y decremento del número del display de 7 segmentos
	CBI DDRB, PB0
	CBI DDRB, PB1

	// Activamos el Pull-up interno
	SBI PORTB, PB0
	SBI PORTB, PB1

	// Inicializamos la variable de contador para el Timer0
	LDI R20, 0

	// Inicializamos la variable de contador para el contador de LEDs
	LDI R21, 0

	// Inicializamos la variable que almacena el número mostrado en el display de 7 segmentos
	LDI R22, 0
	RCALL MOSTRAR_7SEG

	// Colocar R1 en 0, para el funcionamiento correcto del display de 7 segmentos
	CLR R1

	// Definir la variable que contiene las combinaciones hexadecimales de los LEDs en el display de 7 segmentos
	T7S: .DB 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71

	// Variables para guardar el estado anterior de los botones del contador del display de 7 segmentos
	LDI R23, 1
	LDI R24, 1
/****************************************/
// Loop Infinito
MAIN_LOOP:
	RCALL LEER_BOTONES

	IN		R16, TIFR0	// Lee el registro del Timer0
	SBRS	R16, TOV0	// Skip si el Bit 0 (el de TOV0) está en 1
	RJMP	MAIN_LOOP
	SBI		TIFR0,	TOV0	//Indicar Overflow con TOV0 en 1
	LDI		R16, 100		// Cargar nuevamente el valor inicial al Timer0
	OUT		TCNT0, R16
	INC		R20			//Aumenta el contador del Timer0
	CPI		R20, 10		// Cuando compara que ya pasaron 10 Overflow, significa que pasaron 100 ms
	BRNE	MAIN_LOOP
	CLR		R20

	// Mostrar el contador de LEDs
	INC		R21
	CPI		R21, 16
	BRNE	MOSTRAR_BINARIO
	CLR		R21




    RJMP    MAIN_LOOP

/****************************************/
// NON-Interrupt subroutines

MOSTRAR_BINARIO:
	IN		R16, PORTC
	ANDI	R16, 0b11110000
	OR		R16, R21
	OUT		PORTC, R16

	RJMP	MAIN_LOOP

LEER_BOTONES:
	IN		R16, PINB
	SBRS	R16, PB0  // Si está en 0 (presionado), no salta
	RJMP	PB0_PRESIONADO

PB0_NO_PRESIONADO:
	LDI		R23, 1  // Guarda el estado actual = 1
	RJMP	REVISAR_PB1



REVISAR_PB1:
	SBRS	R16, PB1
	RJMP	PB1_PRESIONADO

PB1_NO_PRESIONADO:
	LDI		R24, 1
	RET

PB0_PRESIONADO:
	CPI		R23, 1
	BRNE	REVISAR_PB1

	RCALL	DELAY

	IN		R16, PINB
	SBRS	R16, PB0
	RJMP	CONFIRMAR_PB0
	RJMP	REVISAR_PB1

CONFIRMAR_PB0:
	LDI		R23, 0

	INC		R22
	CPI		R22, 16
	BRLO	OK_PB0
	CLR		R22

OK_PB0:
	RCALL	MOSTRAR_7SEG
	RET

ACTUALIZAR_DISPLAY_PB0:
	RCALL	DELAY
	RCALL	MOSTRAR_7SEG
	RCALL	DELAY

ESPERAR_SOLTAR_PB0:
	IN		R16, PINB
	SBRS	R16, PB0
	RJMP	ESPERAR_SOLTAR_PB0

	LDI		R23, 1
	RJMP	REVISAR_PB1

PB1_PRESIONADO:
	CPI		R24, 1
	BRNE	RETORNAR

	RCALL	DELAY

	IN		R16, PINB
	SBRS	R16, PB1
	RJMP	CONFIRMAR_PB1
	RJMP	RETORNAR

CONFIRMAR_PB1:
	LDI		R24, 0

	CPI		R22, 0
	BRNE	DEC_PB1
	LDI		R22, 15
	RJMP	OK_PB1



OK_PB1:
	RCALL	MOSTRAR_7SEG
	RET

DEC_PB1:
	DEC		R22

ACTUALIZAR_DISPLAY_PB1:
	RCALL	DELAY
	RCALL	MOSTRAR_7SEG
	RCALL	DELAY


ESPERAR_SOLTAR_PB1:
	IN		R16, PINB
	SBRS	R16, PB1
	RJMP	ESPERAR_SOLTAR_PB1

	LDI		R24, 1
	RJMP	RETORNAR


ACTUALIZAR_DISPLAY:
	RCALL	DELAY
	RCALL	MOSTRAR_7SEG
	RCALL	DELAY

RETORNAR:
	RET
	







DELAY:
	LDI R18, 50
DR1:	
	LDI R17, 255
DR2:
	DEC R17
	BRNE DR2
	DEC R18
	BRNE DR1
	RET

MOSTRAR_7SEG:
	LDI ZH, HIGH(T7S << 1)
	LDI ZL, LOW(T7S << 1)

	ADD ZL, R22
	ADC ZH, R1

	LPM R16, Z
	OUT PORTD, R16
	RET

/****************************************/
// Interrupt routines

/****************************************/