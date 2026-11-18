// เล่นเกมบนจอคอมโดยไม่ต้องมีบอร์ด: Verilator (RTL จริง) + SDL2 (หน้าต่าง + คีย์บอร์ด)
//
// คีย์:  ลูกศร = BTNU/D/L/R   Space = BTNC   0-9 = สลับ SW0-SW9   F1-F6 = สลับ SW10-SW15
//        Backspace = CPU_RESETN   Esc = ออก
// 7-seg, LED, RGB LED, สถานะสวิตช์ แสดงบนแถบด้านล่างของหน้าต่าง
//
// เกม: เริ่มที่หน้า TITLE กด Space เริ่มเล่น · ตอนเล่น Space = โจมตี (ร่าง 1 ฟันประชิด, ร่าง 2-4 ยิง;
//      ค้าง Space = ยิงซ้ำ + strafe ไม่หันตัว) · F6 (SW15) = sprint · 3 (SW3) = ได้ไอเทม/EVOLVE ·
//      4 (SW4) = โดนตี HP-1 · 1 (SW1) = เคลียร์ชั้น · 0 (SW0) เปิดประตูบอส L
//      (SW1/3/4 ทำงานตอน "ยกขึ้น" คือสลับจากล่างขึ้นบน) — รายละเอียดดู README.md
//      แผงล่าง: LED4-7 = มอนที่เหลือ, LED8-11 = HP, LED12 = ประตูห้องล็อก, RGB17 แดง = โดนตี
//
// ตัวเลือกสำหรับทดสอบอัตโนมัติ:
//   --frames N        ออกหลัง N เฟรม
//   --shot file.bmp   บันทึกภาพเฟรมสุดท้าย
//   --shot-at N:file.bmp   บันทึกภาพ ณ เฟรม N (ใช้ซ้ำได้หลายครั้ง)
//   --script-file scripts/floor1.txt   อ่านสคริปต์จากไฟล์ (รูปแบบเดียวกัน, # = คอมเมนต์, ขึ้นบรรทัดใหม่ = คั่น)
//   --script "R:10:80,U:90:120,1:200"   กดปุ่มตามช่วงเฟรม (U D L R C) / สลับสวิตช์ที่เฟรมนั้น (0-9 = SW0-9, a-f = SW10-15)
//   --headless | HEADLESS=1   ไม่เรียก SDL เลย, รัน 300 เฟรม (หรือ --frames N) แล้วพิมพ์ fps
//   FRAMESKIP=N | --skip N    จำลอง N เฟรมต่อ 1 เฟรมที่แสดง/อ่านคีย์ (ค่าเริ่มต้น 1 = เหมือนเดิม; กด [ ] ปรับตอนรัน)
//   RENDERER=sw|accel         เลือก SDL renderer (ค่าเริ่มต้น = SDL เลือกเอง)
//   LOG=N                     พิมพ์ "f=<เฟรม> LED=<hex> st fl room px py hp form alive bulbs sm rnd seq boss bhp bx by stun esc" ทุก N เฟรม
//   ปุ่ม C = ตบมือจำลอง (ไมค์ดัง 100 ms) · สคริปต์: K:<เฟรม>
#include "Vtop.h"
#include "verilated.h"
#include "Vtop___024root.h"
#include "Vtop_top.h"               // อ่าน signal /*verilator public*/ (dbg_*) ใน top.v
#include <SDL.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cctype>
#include <string>
#include <vector>
#include <chrono>

#ifndef CE_DIV
#define CE_DIV 4
#endif
static const int W = 640, H = 480, PANEL = 72, SCALE = 1;

struct Act { char key; int from, to; };

// สถานะเกม (game_fsm) สำหรับแถบชื่อหน้าต่าง: หน้า TITLE ยังไม่มีตัวอักษรจนกว่าจะมี font (P5)
static const char* state_name(int s) {
    switch (s) {
        case 0: return "TITLE: press Space";
        case 1: return "PLAY";
        case 2: return "EVOLVE";
        case 3: return "FLOOR CLEAR";
        case 4: return "ESCAPE";
        case 5: return "WIN: press Space";
        case 6: return "GAME OVER: press Space";
        default: return "?";
    }
}

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

static int clap_until = -1;    // เฟรมสุดท้ายที่แสดง CLAP ในชื่อหน้าต่าง
static long clap_left = 0;      // clock ที่เหลือของเสียงตบมือจำลอง (คีย์ C / สคริปต์ K)
static unsigned rng = 12345;
int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    int max_frames = -1;
    std::string shot;
    std::vector<std::pair<int, std::string>> shots;   // --shot-at N:file
    std::vector<Act> script;
    bool headless = false;
    int skip = 1;
    if (const char* e = getenv("HEADLESS")) headless = atoi(e) != 0;
    if (const char* e = getenv("FRAMESKIP")) skip = atoi(e);
    const char* rend = getenv("RENDERER");
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--frames") && i + 1 < argc) max_frames = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--headless")) headless = true;
        else if (!strcmp(argv[i], "--skip") && i + 1 < argc) skip = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--shot") && i + 1 < argc) shot = argv[++i];
        else if (!strcmp(argv[i], "--shot-at") && i + 1 < argc) {
            std::string t = argv[++i]; size_t c = t.find(':');
            if (c != std::string::npos) shots.push_back({atoi(t.c_str()), t.substr(c + 1)});
        }
        else if ((!strcmp(argv[i], "--script") || !strcmp(argv[i], "--script-file")) && i + 1 < argc) {
            std::string s;
            if (!strcmp(argv[i], "--script")) s = argv[++i];
            else {                                     // ไฟล์สคริปต์: # = คอมเมนต์ถึงท้ายบรรทัด, ขึ้นบรรทัดใหม่ = คั่นรายการ
                FILE* f = fopen(argv[++i], "r");
                if (!f) { fprintf(stderr, "cannot open %s\n", argv[i]); return 1; }
                char line[4096];
                while (fgets(line, sizeof line, f)) {
                    std::string l = line;
                    size_t h = l.find('#'); if (h != std::string::npos) l = l.substr(0, h);
                    for (char c : l) if (!isspace((unsigned char)c)) s += c;
                    if (!s.empty() && s.back() != ',') s += ',';
                }
                fclose(f);
            }
            size_t p = 0;
            while (p < s.size()) {
                size_t q = s.find(',', p); if (q == std::string::npos) q = s.size();
                std::string t = s.substr(p, q - p);
                if (t.size() >= 3) {
                    Act a{t[0], 0, 0};
                    sscanf(t.c_str() + 2, "%d:%d", &a.from, &a.to);
                    if (a.to == 0) a.to = a.from;
                    script.push_back(a);
                }
                p = q + 1;
            }
        }
    }

    if (skip < 1) skip = 1;
    if (headless && max_frames <= 0) max_frames = 300;
    SDL_Window* win = nullptr; SDL_Renderer* ren = nullptr; SDL_Texture* tex = nullptr;
    if (!headless) {
        SDL_Init(SDL_INIT_VIDEO);
        win = SDL_CreateWindow("Group10 Dungeon (Verilator)", SDL_WINDOWPOS_CENTERED,
                               SDL_WINDOWPOS_CENTERED, W * SCALE, (H + PANEL) * SCALE, 0);
        // ไม่ใช้ PRESENTVSYNC (จะล็อก fps ที่ 60 และหน่วงลูป)
        Uint32 rflags = 0;
        if (rend && !strcmp(rend, "sw")) rflags = SDL_RENDERER_SOFTWARE;
        else if (rend && !strcmp(rend, "accel")) rflags = SDL_RENDERER_ACCELERATED;
        ren = SDL_CreateRenderer(win, -1, rflags);
        tex = SDL_CreateTexture(ren, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, W, H + PANEL);
    }
    std::vector<uint32_t> px(W * (H + PANEL), 0xFF000000);

    Vtop* top = new Vtop;
    top->CPU_RESETN = 0; top->BTNC = top->BTNU = top->BTND = top->BTNL = top->BTNR = 0; top->SW = 0;

    int x = 0, y = 0, frame = 0, cyc = 0;
    int prev_hs = 1, prev_vs = 1;
    int rgb_seen = 0;
    uint8_t digit[8]; memset(digit, 0x7F, 8);
    bool dpon[8] = {0};                       // จุดทศนิยมต่อหลัก (DP active-low)
    bool quit = false;
    bool kU = 0, kD = 0, kL = 0, kR = 0, kC = 0;
    auto t0 = std::chrono::steady_clock::now();
    auto tw = t0; int fw = 0;      // หน้าต่างวัด fps ราย ~1 วินาที
    double fps = 0;

    while (!quit) {
        // ---------- 1 clock 100 MHz ----------
#if FAST_CLOCK
        // eval ครั้งเดียวต่อ clock: RTL ใช้แต่ posedge -> ไม่ต้อง eval ตอน CLK = 0
        // ตั้งค่า "CLK ก่อนหน้า" ของ trigger posedge ให้เป็น 0 เอง (ชื่อตัวแปรภายในของ Verilator 5.x;
        // ถ้า build ไม่ผ่านกับ Verilator รุ่นอื่น ให้ make FAST_CLOCK=0)
        top->CLK100MHZ = 1;
        top->rootp->__Vtrigprevexpr___TOP__CLK100MHZ__1 = 0;
        top->eval();
#else
        top->CLK100MHZ = 0; top->eval();
        top->CLK100MHZ = 1; top->eval();
#endif
        cyc++;
        // ไมค์จำลอง: PDM สุ่ม ~50% ones, ตอนตบมือ ~90%
        rng ^= rng << 13; rng ^= rng >> 17; rng ^= rng << 5;
        top->M_DATA = clap_left > 0 ? ((rng & 127) < 115) : (rng & 1);
        if (clap_left > 0) clap_left--;
        if (top->rootp->top->dbg_clap) clap_until = frame + 30;      // clap_pulse จาก pdm_mic.v -> CLAP ~0.5 วิ
        if (cyc == 20) top->CPU_RESETN = 1;

        // 7-seg: เก็บ pattern ของหลักที่ anode ติดอยู่ (หลักละ 2^17 clock -> ดูทุก 256 clock พอ)
        if ((cyc & 255) == 0) for (int k = 0; k < 8; k++)
            if (top->AN == (uint8_t)~(1 << k)) {
                digit[k] = (top->CG << 6) | (top->CF << 5) | (top->CE << 4) | (top->CD << 3) |
                           (top->CC << 2) | (top->CB << 1) | top->CA;
                dpon[k] = !top->DP;
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
            static const int logn = getenv("LOG") ? atoi(getenv("LOG")) : 0;
            if (logn > 0 && frame % logn == 0) {
                auto* r = top->rootp;
                printf("f=%d LED=%04x st=%d fl=%d room=%d px=%d py=%d hp=%d form=%d alive=%d bulbs=%x sm=%d rnd=%d seq=%03x"
                       " boss=%d bhp=%d bx=%d by=%d stun=%d esc=%04x\n",
                       frame, top->LED, r->top->dbg_state, r->top->dbg_floor, r->top->dbg_room,
                       r->top->dbg_px, r->top->dbg_py, r->top->dbg_hp, r->top->dbg_form,
                       r->top->dbg_alive, r->top->dbg_bulbs, r->top->dbg_sm, r->top->dbg_round,
                       r->top->dbg_seq, r->top->dbg_bact ? r->top->dbg_floor + 1 : 0, r->top->dbg_bhp,
                       r->top->dbg_bx, r->top->dbg_by, r->top->dbg_stun, r->top->dbg_esc);
                fflush(stdout);
            }

            if (!headless && frame % skip == 0) {
                // แผงสถานะด้านล่าง
                fill(px.data(), 0, H, W, PANEL, 0xFF1E2233);
                for (int k = 7; k >= 0; k--) {             // 7-seg, หลัก 7 ซ้ายสุด
                    int cx = 16 + (7 - k) * 28;
                    fill(px.data(), cx - 3, H + 14, 24, 36, 0xFF101010);
                    draw_char(px.data(), cx, H + 18, seg_char(digit[k]), 0xFFFF4A3A);
                    if (dpon[k]) fill(px.data(), cx + 19, H + 44, 4, 4, 0xFFFF4A3A);
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

                for (auto& sh : shots) if (frame == sh.first) {      // --shot-at: ภาพของเฟรมนี้ (รวมแผง)
                    SDL_Surface* ss = SDL_CreateRGBSurfaceFrom(px.data(), W, H + PANEL, 32, W * 4,
                                                               0x00FF0000, 0x0000FF00, 0x000000FF, 0);
                    SDL_SaveBMP(ss, sh.second.c_str());
                    SDL_FreeSurface(ss);
                }
                SDL_UpdateTexture(tex, nullptr, px.data(), W * 4);
                SDL_RenderClear(ren);
                SDL_RenderCopy(ren, tex, nullptr, nullptr);
                SDL_RenderPresent(ren);
            }

            fw++;
            if (!headless) {   // fps: วัดทุก ~1 วินาที (headless วัดรวมตอนจบ)
                auto t1 = std::chrono::steady_clock::now();
                double dt = std::chrono::duration<double>(t1 - tw).count();
                // ป้ายเพิ่ม: CLAP (~0.5 วิหลังไมค์จับเสียงตบมือ), STUN (บอส 2 มึน)
                static int last_tag = -1;
                int tag = (frame <= clap_until ? 1 : 0) | (top->rootp->top->dbg_stun ? 2 : 0);
                if (dt > 1.0 || tag != last_tag) {
                    char title[220];
                    if (dt > 1.0) { fps = fw / dt; tw = t1; fw = 0; }
                    last_tag = tag;
                    snprintf(title, sizeof title, "Group10 Dungeon - %s%s%s  |  floor %d  %.1f fps  skip=%d  [frame %d]",
                             state_name(top->rootp->top->dbg_state), (tag & 1) ? "  CLAP" : "", (tag & 2) ? "  STUN" : "",
                             top->rootp->top->dbg_floor + 1, fps, skip, frame);
                    SDL_SetWindowTitle(win, title);
                }
            }

            // ---------- input (ทุก skip เฟรม; headless ข้าม) ----------
            if (!headless && frame % skip == 0) {
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
                        else if (k == SDLK_c && d && !e.key.repeat) clap_left = 10000000;   // ตบมือ 100 ms
                        else if (k == SDLK_BACKSPACE) top->CPU_RESETN = !d;
                        else if (d && !e.key.repeat && k == SDLK_LEFTBRACKET) { if (skip > 1) skip--; }
                        else if (d && !e.key.repeat && k == SDLK_RIGHTBRACKET) { if (skip < 64) skip++; }
                        else if (d && !e.key.repeat && k >= SDLK_0 && k <= SDLK_9) top->SW ^= (1 << (k - SDLK_0));
                        else if (d && !e.key.repeat && k >= SDLK_F1 && k <= SDLK_F6) top->SW ^= (1 << (10 + k - SDLK_F1));
                    }
                }
            }
            bool sU = 0, sD = 0, sL = 0, sR = 0, sC = 0;
            for (auto& a : script) {
                if (frame >= a.from && frame <= a.to) {
                    if (a.key == 'U') sU = 1; if (a.key == 'D') sD = 1;
                    if (a.key == 'L') sL = 1; if (a.key == 'R') sR = 1; if (a.key == 'C') sC = 1;
                }
                if (a.key >= '0' && a.key <= '9' && frame == a.from) top->SW ^= (1 << (a.key - '0'));
                if (a.key >= 'a' && a.key <= 'f' && frame == a.from) top->SW ^= (1 << (10 + a.key - 'a'));
                if (a.key == 'K' && frame == a.from) clap_left = 10000000;   // ตบมือ 100 ms
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

    if (!headless && !shot.empty()) {
        SDL_Surface* s = SDL_CreateRGBSurfaceFrom(px.data(), W, H + PANEL, 32, W * 4,
                                                  0x00FF0000, 0x0000FF00, 0x000000FF, 0);
        SDL_SaveBMP(s, shot.c_str());
        SDL_FreeSurface(s);
    }
    if (headless) {
        double dt = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
        printf("headless: frames=%d  time=%.3f s  %.2f fps  (%.1f Mclk/s)\n", frame, dt, frame / dt, cyc / dt / 1e6);
    } else printf("frames=%d  last-window %.1f fps\n", frame, fps);
    top->final();
    delete top;
    if (!headless) SDL_Quit();
    return 0;
}
