# CS2D
Counter Strike inspired 2D game in Godot

![Scrrenshot](https://media.discordapp.net/attachments/361593010862948362/420097225172058122/unknown.png)

## Getting Started

The project uses 2 scenes to handle lobby and 1 singleton to manage multiplayer throughout

## Controls

### Desktop

| Input | Action |
| --- | --- |
| `W` `A` `S` `D` | Move (strafing, independent of where you aim) |
| Mouse | Aim |
| Left Mouse / `Space` | Fire (hold for the rifle, it is automatic) |
| `R` / `Ctrl` | Reload |
| `Shift` | Walk (slower) |
| `1` `2` `3` `4` | Handgun, rifle, shotgun, knife |
| `M` | Team menu |
| `B` | Buy menu |
| `TAB` | Scoreboard (hold) |

The controls screen in the main menu reads the bindings straight out of the
input map, so it cannot drift away from what the game actually does.

Movement is CS-style: you strafe relative to your aim, so the feet animation
switches between `run`, `walk`, `strafe-left` and `strafe-right` depending on
where you move in relation to where you look.

### Touch

On devices reporting a touchscreen the on-screen joystick and the fire/reload
buttons are used instead, and the joystick both aims and moves. The touch
controls are hidden on desktop.

## Menus and HUD

The main menu has four entries, all of them live: **PLAY** hosts or joins a
match, **SETTINGS** switches fullscreen, vertical sync, the crosshair and the
FPS counter, **CONTROLS** lists the current key bindings, and **QUIT** exits.
Settings take effect the moment you flip them and are written to
`user://settings.cfg`, so they survive a restart. The player name is
remembered the same way.

In game, `M` opens the team menu. It blocks aiming, movement and firing
while it is open, and the team you pick takes effect on the next round, the
way Counter-Strike does it.

The HUD follows the same layout: health bottom left, weapon and magazine
bottom right, the round score in a bar at the top with the team colours, and
a crosshair in the middle that opens up with your spread.

Hold `TAB` for the scoreboard — kills, deaths, assists and money per player,
grouped by side, with the dead greyed out. The killfeed in the top right
names the killer, the weapon and the victim in the killer's team colour.

The radar sits top left over the map's own overview image. Team mates are
always on it; enemies appear only while you can actually see them, so it
passes on what you have rather than acting as a wallhack. The kill that
feeds all of this is decided by the server: the victim remembers who hit it
and how much, the server picks the killer and hands the assist to whoever
else did at least 40 damage.

## Weapons

| Weapon | Magazine | Damage | Fire mode | Armour pierced |
| --- | --- | --- | --- | --- |
| Handgun | 12 | 25 | Semi | 25% |
| Rifle | 30 | 22 | Automatic | 70% |
| Shotgun | 8 | 13 per pellet, 6 pellets | Semi, wide cone | 30% |
| Knife | - | 55 | Melee, 190 px in front of you | 85% |

The rate of fire is the playback speed of each weapon's shoot animation, so
the picture and the timing can never drift apart. Sprite frames are loaded
per weapon on first use and shared by every player, because holding all 420
frames at once would keep about 90 MB of textures open.

### Accuracy

Standing still, the first shot goes exactly where you point. Everything else
widens the cone: running adds spread in proportion to your speed, and every
shot adds recoil that decays again once you stop firing. Each weapon also
has a fixed spray pattern, so holding the trigger pulls the shots along a
learnable path that you can compensate for with the mouse, and the pattern
starts over after a short pause. Damage falls off with distance down to a
floor, and the heavier the weapon, the slower you carry it.

### Movement

Movement has weight. You accelerate up to speed and coast to a stop instead
of starting and stopping instantly, so you cannot fire accurately the moment
you let go of a key. Pressing the opposite direction brakes far harder than
letting go — 4 frames instead of 9 — which is counter-strafing: tap the
other key and you are accurate again almost at once.

## Teams and rounds

Players are split into `T` and `CT`. The server balances the teams as people
join and is the only one that decides, clients only ask; use the Switch Team
button in the lobby. Team mates cannot damage each other, and each team has
its own base to spawn in.

## Match format

The match follows Counter-Strike's competitive format:

| | |
| --- | --- |
| Rounds | 30, first team to 16 wins |
| Halftime | after round 15, sides swap and the score goes with the players |
| Freeze time | 10 seconds at the spawn, aim and buy but do not move |
| Round time | 1:55 — if it runs out the CT side takes the round |
| Round end | 7 seconds before the next round starts |

At 15:15 the match is a draw. When a match is over the host gets a button to
start a new one, which resets score, rounds and money.

## Money and the buy menu

`B` opens the buy menu. You can only buy during the freeze time, and gear is
gone again when the round ends. Everyone always carries a handgun and a
knife; the rifle, the shotgun and the kevlar vest have to be bought, and a
weapon you have not bought cannot be selected with the number keys. Kevlar
soaks up half of the incoming damage until it is used up.

Money follows Counter-Strike as well: you start on $800 and cannot hold more
than $16000. Winning a round pays $3250. Losing pays $1400 and climbs to
$1900, $2400, $2900 and $3400 while the losing streak lasts, and drops back
one step for every round the team wins. A kill pays what the weapon is
worth: $300 for the handgun and the rifle, $900 for the shotgun and $1500
for the knife.

Note that damage is still evaluated by each peer for itself, so round
results, kill rewards and the score are only as trustworthy as the clients
are.

### Testing

#### Configuring Server
To test currently, 
Run the project, enter a player name under PLAY and press CREATE SERVER,
then note the addresses listed under THIS MACHINE in the lobby

#### Configuring Client
Run it again in same Computer or another connected to same network
Enter player name Enter the correct IP from ones listed in server lobby 
Generally 127.0.0.1 if in same computer or the second IP in server IP list if on same network
Match the port (default is fine)
Create client

#### Starting Game
Once all players are listed in Server's lobby Server can start the game,

Game will end when only one player is left
Server can only [re]start the game
