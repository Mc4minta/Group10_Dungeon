// เล่นเกมบนจอคอมโดยไม่ต้องมีบอร์ด: Verilator (RTL จริง) + SDL2 (หน้าต่าง + คีย์บอร์ด)
//
// คีย์:  ลูกศร = BTNU/D/L/R   Space = BTNC   0-9 = สลับ SW0-SW9   F1-F6 = สลับ SW10-SW15
//        Backspace = CPU_RESETN   Esc = ออก
// 7-seg, LED, RGB LED, สถานะสวิตช์ แสดงบนแถบด้านล่างของหน้าต่าง
//
// ตัวเลือกสำหรับทดสอบอัตโนมัติ:
//   --frames N        ออกหลัง N เฟรม
//   --shot file.bmp   บันทึกภาพเฟรมสุดท้าย
//   --script "R:10:80,U:90:120,1:200"   กดปุ่มตามช่วงเฟรม (U D L R C) / สลับสวิตช์ (0-9) ที่เฟรมนั้น
#include "Vtop.h"
#include "verilated.h"
#include <SDL.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#include <chrono>

#ifndef CE_DIV
#define CE_DIV 4
#endif
static const int W = 640, H = 480, PANEL = 72, SCALE = 1;

struct Act { char key; int from, to; };

// 7-seg (active-low gfedcba) -> ตัวอักษร
static char seg_char(uint8_t s) {
    switch (s & 0x7F) {
        case 0x40: return '0'; case 0x79: return '1'; case 0x24: return '2'; case 0x30: return '3';
        case 0x19: return '4'; case 0x12: return '5'; case 0x02: return '6'; case 0x78: return '7';
        case 0x00: return '8'; case 0x10: return '9'; case 0x3F: return '-'; case 0x7F: return ' ';
        default: return '?';
    }
}

// ตัวเลข 3x5 สำหรับวาด 7-seg บนแผง (วาดเองไม่ต้องใช้ฟอนต์)
static const char* GLYPH[] = {
    "111101101101111", "010110010010111", "111001111100111", "111001111001111", "101101111001001",
    "111100111001111", "111100111101111", "111001001001001", "111101111101111", "111101111001111",
};

static void fill(uint32_t* px, int x, int y, int w, int h, uint32_t c) {
    for (int j = y; j < y + h; j++)
        for (int i = x; i < x + w; i++)
            if (i >= 0 && i < W && j >= 0 && j < H + PANEL) px[j * W + i] = c;
}

static void draw_char(uint32_t* px, int x, int y, char ch, uint32_t c) {
    if (ch == '-') { fill(px, x, y + 16, 18, 4, c); return; }
    if (ch < '0' || ch > '9') return;
    const char* g = GLYPH[ch - '0'];
    for (int r = 0; r < 5; r++)
        for (int k = 0; k < 3; k++)
            if (g[r * 3 + k] == '1') fill(px, x + k * 6, y + r * 6, 6, 6, c);
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    int max_frames = -1;
    std::string shot;
    std::vector<Act> script;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--frames") && i + 1 < argc) max_frames = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--shot") && i + 1 < argc) shot = argv[++i];
        else if (!strcmp(argv[i], "--script") && i + 1 < argc) {
            std::string s = argv[++i];
            size_t p = 0;
            while (p < s.size()) {
                size_t q = s.find(',', p); if (q == std::string::npos) q = s.size();
                std::string t = s.substr(p, q - p);
                Act a{t[0], 0, 0};
                sscanf(t.c_str() + 2, "%d:%d", &a.from, &a.to);
                if (a.to == 0) a.to = a.from;
                script.push_back(a);
                p = q + 1;
            }
        }
    }

    SDL_Init(SDL_INIT_VIDEO);
    SDL_Window* win = SDL_CreateWindow("Group10 Dungeon (Verilator)", SDL_WINDOWPOS_CENTERED,
                                       SDL_WINDOWPOS_CENTERED, W * SCALE, (H + PANEL) * SCALE, 0);
    SDL_Renderer* ren = SDL_CreateRenderer(win, -1, 0);
    SDL_Texture* tex = SDL_CreateTexture(ren, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, W, H + PANEL);
    std::vector<uint32_t> px(W * (H + PANEL), 0xFF000000);

    Vtop* top = new Vtop;
    top->CPU_RESETN = 0; top->BTNC = top->BTNU = top->BTND = top->BTNL = top->BTNR = 0; top->SW = 0;

    int x = 0, y = 0, frame = 0, cyc = 0;
    int prev_hs = 1, prev_vs = 1;
    int rgb_seen = 0;
    uint8_t digit[8]; memset(digit, 0x7F, 8);
    bool quit = false;
    bool kU = 0, kD = 0, kL = 0, kR = 0, kC = 0;
    auto t0 = std::chrono::steady_clock::now();
    double fps = 0;

    while (!quit) {
        // ---------- 1 clock 100 MHz ----------
        top->CLK100MHZ = 0; top->eval();
        top->CLK100MHZ = 1; top->eval();
        cyc++;
        if (cyc == 20) top->CPU_RESETN = 1;

        // 7-seg: เก็บ pattern ของหลักที่ anode ติดอยู่ (หลักละ 2^17 clock -> ดูทุก 256 clock พอ)
        if ((cyc & 255) == 0) for (int k = 0; k < 8; k++)
            if (top->AN == (uint8_t)~(1 << k)) {
                digit[k] = (top->CG << 6) | (top->CF << 5) | (top->CE << 4) | (top->CD << 3) |
                           (top->CC << 2) | (top->CB << 1) | top->CA;
            }

        // RGB LED เป็น PWM สว่างแค่ ~6% -> จำว่าเฟรมนี้เคยติดสีไหน
        rgb_seen |= (top->LED16_R << 5) | (top->LED16_G << 4) | (top->LED16_B << 3) |
                    (top->LED17_R << 2) | (top->LED17_G << 1) | top->LED17_B;

        // ---------- VGA: อ่าน 1 ครั้งต่อพิกเซล ----------
        if (cyc % CE_DIV != 0) continue;
        int hs = top->VGA_HS, vs = top->VGA_VS;
        if (prev_hs && !hs) x = 656;                   // ขอบหน้า hsync = h 656
        if (prev_vs && !vs) {                          // ขอบหน้า vsync = v 490 -> จบเฟรม
            y = 490; x = 0;
            frame++;

            // แผงสถานะด้านล่าง
            fill(px.data(), 0, H, W, PANEL, 0xFF1E2233);
            for (int k = 7; k >= 0; k--) {             // 7-seg, หลัก 7 ซ้ายสุด
                int cx = 16 + (7 - k) * 28;
                fill(px.data(), cx - 3, H + 14, 24, 36, 0xFF101010);
                draw_char(px.data(), cx, H + 18, seg_char(digit[k]), 0xFFFF4A3A);
            }
            for (int i = 0; i < 16; i++) {             // LED15..0
                bool on = (top->LED >> (15 - i)) & 1;
                fill(px.data(), 260 + i * 14, H + 16, 10, 10, on ? 0xFF4CFF4C : 0xFF2C3A2C);
                bool sw = (top->SW >> (15 - i)) & 1;   // สวิตช์ใต้ LED
                fill(px.data(), 260 + i * 14, H + (sw ? 34 : 44), 10, 10, 0xFFC8C8C8);
            }
            uint32_t rgb16 = 0xFF000000 | ((rgb_seen & 32) ? 0xFF0000 : 0) | ((rgb_seen & 16) ? 0xFF00 : 0) | ((rgb_seen & 8) ? 0xFF : 0);
            uint32_t rgb17 = 0xFF000000 | ((rgb_seen & 4) ? 0xFF0000 : 0) | ((rgb_seen & 2) ? 0xFF00 : 0) | ((rgb_seen & 1) ? 0xFF : 0);
            rgb_seen = 0;
            fill(px.data(), 500, H + 18, 26, 26, rgb16 == 0xFF000000 ? 0xFF303030 : rgb16);
            fill(px.data(), 536, H + 18, 26, 26, rgb17 == 0xFF000000 ? 0xFF303030 : rgb17);

            SDL_UpdateTexture(tex, nullptr, px.data(), W * 4);
            SDL_RenderClear(ren);
            SDL_RenderCopy(ren, tex, nullptr, nullptr);
            SDL_RenderPresent(ren);

            auto t1 = std::chrono::steady_clock::now();
            double dt = std::chrono::duration<double>(t1 - t0).count();
            if (dt > 1.0) {
                char title[128];
                fps = frame / dt;
                snprintf(title, sizeof title, "Group10 Dungeon (Verilator)  %.1f fps  [frame %d]", fps, frame);
                SDL_SetWindowTitle(win, title);
            }

            // ---------- input ----------
            SDL_Event e;
            while (SDL_PollEvent(&e)) {
                if (e.type == SDL_QUIT) quit = true;
                if (e.type == SDL_KEYDOWN || e.type == SDL_KEYUP) {
                    bool d = (e.type == SDL_KEYDOWN);
                    SDL_Keycode k = e.key.keysym.sym;
                    if (k == SDLK_UP) kU = d;
                    else if (k == SDLK_DOWN) kD = d;
                    else if (k == SDLK_LEFT) kL = d;
                    else if (k == SDLK_RIGHT) kR = d;
                    else if (k == SDLK_SPACE) kC = d;
                    else if (k == SDLK_ESCAPE && d) quit = true;
                    else if (k == SDLK_BACKSPACE) top->CPU_RESETN = !d;
                    else if (d && !e.key.repeat && k >= SDLK_0 && k <= SDLK_9) top->SW ^= (1 << (k - SDLK_0));
                    else if (d && !e.key.repeat && k >= SDLK_F1 && k <= SDLK_F6) top->SW ^= (1 << (10 + k - SDLK_F1));
                }
            }
            bool sU = 0, sD = 0, sL = 0, sR = 0, sC = 0;
            for (auto& a : script) {
                if (frame >= a.from && frame <= a.to) {
                    if (a.key == 'U') sU = 1; if (a.key == 'D') sD = 1;
                    if (a.key == 'L') sL = 1; if (a.key == 'R') sR = 1; if (a.key == 'C') sC = 1;
                }
                if (a.key >= '0' && a.key <= '9' && frame == a.from) top->SW ^= (1 << (a.key - '0'));
            }
            top->BTNU = kU | sU; top->BTND = kD | sD; top->BTNL = kL | sL; top->BTNR = kR | sR; top->BTNC = kC | sC;

            if (max_frames > 0 && frame >= max_frames) quit = true;
        }
        prev_hs = hs; prev_vs = vs;

        if (x < W && y < H) {
            uint32_t r = top->VGA_R * 17, g = top->VGA_G * 17, b = top->VGA_B * 17;
            px[y * W + x] = 0xFF000000 | (r << 16) | (g << 8) | b;
        }
        if (++x == 800) { x = 0; y = (y == 524) ? 0 : y + 1; }
    }

    if (!shot.empty()) {
        SDL_Surface* s = SDL_CreateRGBSurfaceFrom(px.data(), W, H + PANEL, 32, W * 4,
                                                  0x00FF0000, 0x0000FF00, 0x000000FF, 0);
        SDL_SaveBMP(s, shot.c_str());
        SDL_FreeSurface(s);
    }
    printf("frames=%d  avg %.1f fps\n", frame, fps);
    top->final();
    delete top;
    SDL_Quit();
    return 0;
}
