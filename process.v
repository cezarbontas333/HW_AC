`timescale 1ns / 1ps

module process(
	input clk,				// clock 
	input [23:0] in_pix,	// valoarea pixelului de pe pozitia [in_row, in_col] din imaginea de intrare (R 23:16; G 15:8; B 7:0)
	output reg [5:0] row, col, 	// selecteaza un rand si o coloana din imagine
	output reg out_we, 			// activeaza scrierea pentru imaginea de iesire (write enable)
	output reg [23:0] out_pix,	// valoarea pixelului care va fi scrisa in imaginea de iesire pe pozitia [out_row, out_col] (R 23:16; G 15:8; B 7:0)
	output mirror_done,		// semnaleaza terminarea actiunii de oglindire (activ pe 1)
	output gray_done,		// semnaleaza terminarea actiunii de transformare in grayscale (activ pe 1)
	output filter_done);	// semnaleaza terminarea actiunii de aplicare a filtrului de sharpness (activ pe 1)

// TODO add your finite state machines here
`define MIRROR_INIT 0              // Starea de incepere a operatiunii de oglindire.
`define MIRROR_STEP1 1         // Aici copiem in memorie pixelul din partea stanga.
`define MIRROR_STEP2 2			 // Aici copiem in memorie pixelul oglindit, apoi scriem pixelul original in locul celui oglindit, si vedem unde
										 // ne situam in partea din stanga. Aici putem sa vedem daca se termina procesul de oglidire, caz in care se
										 // activeaza mirror_done.
`define MIRROR_STEP3 3			 // Aici scriem pixelul oglindit in locul celui original din stanga, apoi in functie de mirror_done, trecem la 
										 // urmatoarea operatie sau continuam cu oglinditul.
`define MIRROR_FINISH 4
`define GRAYSCALE_INIT 5										 
`define GRAYSCALE_WRITE 6
`define GRAYSCALE_FINISH 7										 

reg [4:0] state, next_state;
reg [5:0] next_row, next_col;  // Solutia pentru a nu pierde progresul legat de indexii la MIRROR_STEP2 este sa retinem separat unde vrem sa ne ducem
								       // inainte de a suprascrie pe matrice pixelii.
reg [23:0]pix_n, pix_m;        // Buffer pentru citirea pixelilor.
reg [7:0]min, max;             // Pentru GRAYSCALE_WRITE.

// Macrouri pentru valorile individuale ale culorilor pt intrare si iesire.
`define R_IN in_pix[23:16]
`define G_IN in_pix[15:8]
`define B_IN in_pix[7:0]
`define R_OUT out_pix[23:16]
`define G_OUT out_pix[15:8]
`define B_OUT out_pix[7:0]

always @(posedge clk) begin
	state <= next_state;
	row <= next_row;
	col <= next_col;
	
end

assign mirror_done = state >= `MIRROR_FINISH;
assign gray_done = state >= `GRAYSCALE_FINISH;

always @(*) begin
	case(state)
		// Sectiunea de implementare a operatiunii de oglindire
		`MIRROR_INIT: begin
			next_row = 0;
			next_col = 0;
			next_state = `MIRROR_STEP1;
		end
		`MIRROR_STEP1: begin
			out_we = 0;
			pix_n = in_pix;
			next_row = 63 - row;
			next_state = `MIRROR_STEP2;
		end
		`MIRROR_STEP2: begin
			pix_m = in_pix;
			out_we = 1;
			out_pix = pix_n;
			/*
			Acest cod este un exemplu pentru de ce nu ar trebui sa fiu angajat. Code of shame
			
			if (row == 32) begin
				if (col == 63) begin
					// ??? Se vede ce ma pricep.
					// Este un workaround idiot ca sa nu refac logica codului, ca altfel ma pierd. Daca aveam return sau call de functie...
				end
				else begin
					// next_col = col + 1;
					// next_row = 0;
					// Trebuie refacut in MIRROR_STEP3 verificarea pentru resetarea pozitiei randului, ca altfel imi pleaca la plimbare...
					// De 2 ori mi-am luat teapa cu schimbarile de valori inaintea scrierii pe pozitie...
				end
			end
			else begin
				next_row = 63 - row;
			end
			*/
			next_row = 63 - row;
			next_state = `MIRROR_STEP3;
		end
		// Hai ca s-au mutat majoritatea pozitionarilor in MIRROR_STEP3
		`MIRROR_STEP3: begin
			out_we = 1;
			out_pix = pix_m;
			if (row == 31) begin
				if(col == 63) begin
					next_state = `MIRROR_FINISH;
				end
				else begin
					next_col = col + 1;
					next_row = 0;
					next_state = `MIRROR_STEP1;
				end
			end
			else begin
				next_row = row + 1;
				next_state = `MIRROR_STEP1;
			end
		end
		`MIRROR_FINISH: begin
			next_state = `GRAYSCALE_INIT;
		end
		
		// Sectiunea de implementare a operatiunii de grayscaling
		`GRAYSCALE_INIT: begin
			next_row = 0;
			next_col = 0;
			out_we = 0;
			next_state = `GRAYSCALE_WRITE;
		end
		`GRAYSCALE_WRITE: begin
			out_we = 1;
			min = `R_IN;
			max = `R_IN;
			if (min > `G_IN) min = `G_IN;
			if (min > `B_IN) min = `B_IN;
			if (max < `G_IN) max = `G_IN;
			if (max < `B_IN) max = `B_IN;
			`G_OUT = (min + max) / 2;
			`R_OUT = 0;
			`B_OUT = 0;
			if (row < 63) next_state = `GRAYSCALE_WRITE;
			else if(row == 63 && col == 63) next_state = `GRAYSCALE_FINISH;
			if (col < 63) next_col = col + 1;
			else begin
				next_col = 0;
				next_row = row + 1;
			end
		end
		`GRAYSCALE_FINISH: begin
			// Se termina programul!
		end
		// Cam lasam outputul activat. Nu cred ca e de buna practica asta.
			
		// Sectiunea de implementare a operatiunii de filtrare
		// Nu mai implementez filtrarea din lipsa de timp (eu de vina ca fac tema pe ultima suta de metri), dar macar de consolare o sa detaliez
		// ideea pentru implementare.

		// Cazul default, ca sa avem failsafe.
		default: begin
			next_row = 0;
			next_col = 0;
			next_state = `MIRROR_INIT;
		end
	endcase
end

endmodule
