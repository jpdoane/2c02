
parameter PPUCTRL_ADDR   =3'h0;
parameter PPUMASK_ADDR   =3'h1;
parameter PPUSTATUS_ADDR =3'h2;
parameter OAMADDR_ADDR   =3'h3;
parameter OAMDATA_ADDR   =3'h4;
parameter PPUSCROLL_ADDR =3'h5;
parameter PPUADDR_ADDR   =3'h6;
parameter PPUDATA_ADDR   =3'h7;
// parameter OAMDMA         =8'h4014;

parameter PPUCTRL_V = 7;    // nmi enable
parameter PPUCTRL_P = 6;    // master/slave
parameter PPUCTRL_H = 5;    // sprite height
parameter PPUCTRL_B = 4;    // background tile select
parameter PPUCTRL_S = 3;    // sprite tile select
parameter PPUCTRL_I = 2;    // increment mode
// parameter PPUCTRL_N = 8'b00000011;    // nametable select

parameter CHR_DEPTH  = 13;
parameter VRAM_DEPTH = 11;
parameter PAL_DEPTH  = 5;
parameter ADDR_DEPTH = 15;

parameter SCREEN_WIDTH =  9'd256;
parameter SCREEN_HEIGHT = 9'd240;
parameter CYCLE_LAST =    9'd340;
parameter CYCLE_RESETON = 9'd279;
parameter CYCLE_RESETOFF = 9'd303;
parameter CYCLE_BADFETCH = 9'd336;
parameter CYCLE_SPDONE = 9'd320;

parameter FRAME_HEIGHT = 9'd262;

parameter OAM_IDLE = 2'h0;
parameter OAM_CLEAR = 2'h1;
parameter OAM_UPDATE = 2'h2;
parameter OAM_FETCH = 2'h3;
