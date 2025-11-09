![Fireflies Animation](https://raw.githubusercontent.com/mikej1977/JB_Fireflies/refs/heads/main/assets/fireflies_anim.gif)

# JB's Fireflies Version 2.8
_Add some ambiance to your summer nights in Project Zomboid_

## B41 and B42.12+
Unless I can figure out depth mapping, I'm probably done updating this for awhile.

---

## Performance Considerations
- Most of the time, unless you really, really like fireflies, you'll have 20–50 on screen.  
- **FPS dips** = too many fireflies.  
- **Stutters** = spawn area around the player is too large, or oversampling is too high.  

---

![Sandbox Options](https://raw.githubusercontent.com/mikej1977/JB_Fireflies/refs/heads/main/assets/sandbox-options.jpg)

### Spawn fireflies every # ticks
How often new fireflies are spawned on screen. A tick is basically a frame.

### Minimum amount of fireflies to spawn every # ticks
The minimum number of fireflies to try and spawn every tick.

### Maximum amount of fireflies to spawn every # ticks
The maximum number of fireflies to try and spawn every tick.

### Maximum number of fireflies to render on screen
The maximum number of fireflies to render at any time.

### How many squares around the player that fireflies spawn
The amount of squares around the player that fireflies will try to spawn.

### How many times to oversample squares to get a desired spawn location
How many times to loop over the area to try and find the desired spawn location.

### Number of days fireflies gradually fade in and out
How many days before and after that fireflies begin to slowly taper in and out.

### Day of the year when the firefly season begins
The day of the year that fireflies will reach their full spawn rate. See note below.

### Day of the year when the firefly season ends
The day of the year that fireflies will end their full spawn rate. See note below.

### Hide fireflies that your player shouldn't be able to see
Hide any fireflies that your player would not be able to see (e.g. behind you).

---

### A note about Days
"Day" is a rough estimate that assumes every month has 30 days.

To find your day, multiply month × 30 and add how many days into the month, e.g.:

- `0` = January, `11` = December  
- June 15th → `5 × 30 + 15 = 165`  
- January 9th → `0 × 30 + 9 = 9`  

Fireflies will slowly start appearing before your start day and gradually thin out after your end day.

---

## Some Information
- Fireflies like warmer weather. If it's too chilly, there won't be as many (or any).  
- They don't like the rain. If it's raining, there won't be as many (or any).  
- Spawns will waterfall from shorelines → trees → grass, with some random spawns allowed.  
- If there are not enough ideal spawn locations, they will spawn in more random places.  
- They won't spawn very often over open water or pavement.  
- They won't be as bright in lit areas.  
- They will try and avoid a small area around the player.  

---

**Note:** If you're teleporting around, you may get an error if we try to update on a square that just vanished.

---

## Currently Exploring
- Depth mapping (the dream)  
- A more user‑friendly day selector  
