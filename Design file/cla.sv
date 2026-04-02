`timescale 1ns / 1ps

/**
 * @param a first 1-bit input
 * @param b second 1-bit input
 * @param g whether a and b generate a carry
 * @param p whether a and b would propagate an incoming carry
 */
module gp1(input logic a, b,
           output logic g, p);
   assign g = a & b;
   assign p = a | b;
endmodule

/**
 * Computes aggregate generate/propagate signals over a 4-bit window.
 * @param gin incoming generate signals
 * @param pin incoming propagate signals
 * @param cin the incoming carry
 * @param gout whether these 4 bits internally would generate a carry-out (independent of cin)
 * @param pout whether these 4 bits internally would propagate an incoming carry from cin
 * @param cout the carry outs for the low-order 3 bits
 */
module gp4(input logic [3:0] gin, pin,
           input logic cin,
           output logic gout, pout,
           output logic [2:0] cout);

    always_comb
    begin
        gout = gin[3] | (pin[3] & gin[2]) | (pin[3] & pin[2] & gin[1])
                        | (pin[3] & pin[2] & pin[1] & gin[0]);
        pout = &pin ;

        cout[0] = gin[0] | (pin[0] & cin) ;
        cout[1] = gin[1] | (pin[1] & gin[0]) | (pin[1] & pin[0] & cin) ;
        cout[2] = gin[2] | (pin[2] & gin[1]) | (pin[2] & pin[1] & gin[0])
                            | (pin[2] & pin[1] & pin[0] & cin) ;
    end
endmodule

/** Same as gp4 but for an 8-bit window instead */
module gp8(input logic [7:0] gin, pin,
           input logic cin,
           output logic gout, pout,
           output logic [6:0] cout);

   logic pout_low, gout_low, pout_high, gout_high ;
   logic [3:0] lower_cout ;
   logic [2:0] upper_cout ;
   always_comb
   begin
      gout_low = gin[3] | (pin[3] & gin[2]) | (pin[3] & pin[2] & gin[1])
                        | (pin[3] & pin[2] & pin[1] & gin[0]) ;
      pout_low = &pin[3:0] ;
      gout_high = gin[7] | (pin[7] & gin[6]) | (pin[7] & pin[6] & gin[5])
                        | (pin[7] & pin[6] & pin[5] & gin[4]) ;
      pout_high = &pin[7:4] ;

      lower_cout[0] = gin[0] | (pin[0] & cin) ;
      lower_cout[1] = gin[1] | (pin[1] & gin[0]) | (pin[1] & pin[0] & cin) ;
      lower_cout[2] = gin[2] | (pin[2] & gin[1]) | (pin[2] & pin[1] & gin[0])
                           | (pin[2] & pin[1] & pin[0] & cin) ;
      lower_cout[3] = gin[3] | (pin[3] & gin[2]) |(pin[3] & pin[2] & gin[1])
                        | (pin[3] & pin[2] & pin[1] & gin[0])
                        | (pin[3] & pin[2] & pin[1] & pin[0] & cin) ;
   end
   logic mid_cout ;
   assign mid_cout = lower_cout[3] ;
   always_comb
   begin
      gout = gout_high | (pout_high & gout_low) ;
      pout = pout_high & pout_low ;

      upper_cout[0] = gin[4] | (pin[4] & mid_cout) ;
      upper_cout[1] = gin[5] | (pin[5] & gin[4]) | (pin[5] & pin[4] & mid_cout) ;
      upper_cout[2] = gin[6] | (pin[6] & gin[5]) | (pin[6] & pin[5] & gin[4])
                        | (pin[6] & pin[5] & pin[4] & mid_cout) ;
   end

   assign cout = {upper_cout, lower_cout} ;
endmodule

module cla
  (input logic  [31:0]  a, b,
   input logic         cin,
   output logic [31:0] sum,
   output logic carry_out);

   logic [31:0] g1, p1 ;
   logic [7:0] g4, p4 ;
   logic g32, p32 ;
   logic [30:0] cout ;

   genvar i ;
   generate
      for(i=0 ; i < 32 ; i++)
      begin : g_gp1
         gp1 unit(.a(a[i]), .b(b[i]), .g(g1[i]), .p(p1[i])) ;
      end
      for(i=0 ; i < 31 ; i = i+4)
      begin : g_gp4
         if(i == 0)
            gp4 unit(.gin(g1[i+3:i]), .pin(p1[i+3:i]), .cin(cin),
                     .gout(g4[i/4]), .pout(p4[i/4]), .cout(cout[i+2:i])) ;
         else
            gp4 unit(.gin(g1[i+3:i]), .pin(p1[i+3:i]), .cin(cout[i-1]),
                     .gout(g4[i/4]), .pout(p4[i/4]), .cout(cout[i+2:i])) ;
      end
   endgenerate

   gp8 unit(.gin(g4[7:0]), .pin(p4[7:0]), .cin(cin), .gout(g32), .pout(p32),
            .cout({cout[27],cout[23],cout[19],cout[15],cout[11],cout[7],cout[3]})) ;

   assign sum[31:0] = a[31:0] ^ b[31:0] ^ {cout[30:0],cin} ;
   assign carry_out = g32 | p32 & cout[30] ;
endmodule


