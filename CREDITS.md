# Credits

The Chosen One (Group 10, CPE222, KMUTT) uses third-party art. The same names are shown in the game on the title screen pages CREDITS 2 to 8 (press BTNR on the title screen). Please follow each licence before you reuse anything.

## Team

The names on the CREDITS 3 to 5 screens come from [`docs/TEAM.txt`](docs/TEAM.txt) (one name and student ID per line). Supervisor: Dr. Taweechai Nuntawisuttiwong.

## Art packs

| Pack | Author | Page | Licence (summary) | Used for |
| --- | --- | --- | --- | --- |
| 24x24 Pixel Dungeon Asset Pack | Pixel_Poem | <https://pixel-poem.itch.io/dungeon-assetpuck> | Free and commercial use, modification allowed | Enemies, animations / VFX, tileset, UI, items, environment |
| Minifantasy Dungeon | Krishna Palacio | <https://krishna-palacio.itch.io/minifantasy-dungeon> | **Free licence: non-commercial use only. You must credit Krishna Palacio and send him a link to the finished project.** | Characters, tileset, buildings and objects |
| Hearts and health bar | VampireGirl (itch.io: fliflifly) | <https://fliflifly.itch.io/hearts-and-health-bar> | CC0 | Heart HUD icons |
| Animated Orb Assets | axiale | <https://axiale.itch.io/animated-orb-assets> | Free, credit appreciated | Orb sprites (the maze ball) |

Obligations:

- **Minifantasy Dungeon:** the credit "Krishna Palacio" is on screen (CREDITS 7). The licence also asks for a link to the finished project to be sent to the author. This project is a non-commercial university project.
- The other packs need no further action. Credit is given for all of them.

## Not credited on screen

- **Music.** The floor music is a short square-wave arrangement of the melody of a commercial song ("Connect"), entered as notes in `sprites/music/connect.txt`. The artist and the permission are not recorded in the repository, so the song is not credited on screen. This is open: see `docs/BOARD_TEST_STEPS.md`.
- **`my_asset/ui/MediavelFree.png`** is a UI sheet that is copied into the repository but not used by the game. Its author and licence are not recorded.
- **Enemy Animations Set** (`my_asset/Enemy_Animations_Set.zip`, `my_asset/enemies/`): the skeleton and vampire sheets used for monsters and bosses. The author and licence of this download are not recorded in the repository.

## Where the files are

`my_asset/` holds the source pictures, `sprites/*.json` says which cells are used, and `docs/SPRITE_STATUS.md` lists the status of every sprite. The pictures are converted into `mem/*.mem` by the scripts in `scripts/`.
