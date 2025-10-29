# JB_Fireflies Version 2.8

[img]https://raw.githubusercontent.com/mikej1977/JB_Fireflies/refs/heads/main/assets/fireflies_anim.gif[/img]
[h1][b]JB's Fireflies Version 2.8[/b][/h1]
[b]Add some ambiance to your summer nights in Project Zomboid[/b]
[h2]B42 Only[/h2]
Unless I can figure out depth mapping, I'm probably done updating this for awhile

[hr][/hr]
[b]Performance Considerations:[/b]
 - Most of the time, unless you really, really like fireflies, you'll have 20-50 on screen.
 - FPS dips = too many fireflies. 
 - Stutters = too large of a spawn area around the player or oversampling is too high

[hr][/hr]
[img]https://raw.githubusercontent.com/mikej1977/JB_Fireflies/refs/heads/main/assets/sandbox-options.jpg[/img]
[b]Spawn fireflies every # ticks[/b]
    How often are new fireflies spawned on screen. A tick is basically a frame. 

[b]Minimum amount of fireflies to spawn every # ticks[/b]
    The minimum number of fireflies to try and spawn every tick.

[b]Maximum amount of fireflies to spawn every # ticks[/b]
    The maximum number of fireflies to try and spawn every tick.

[b]Maximum number of fireflies to render on screen[/b]
    The maximum number of fireflies to render at any time.

[b]How many squares around the player that fireflies spawn[/b]
    The amount of squares around the player that fireflies will try to spawn. 

[b]How many times to oversample squares to get a desired spawn location[/b]
    How many times to loop over the area to try and find the desired spawn location.

[b]Number of days fireflies gradually fade in and out[/b]
    How many days before and after that fireflies being to slowly taper in and out.

[b]Day of the year when the firefly season begins[/b]
    The day of the year that fireflies will reach their full spawn rate. See note below.

[b]Day of the year when the firefly season ends[/b]
    The day of the year that fireflies will end their full spawn rate. See note below.

[b]Hide fireflies that your player shouldn't be able to see[/b]
    Hide any fireflies that your player would not be able to see, e.g. behind you.

A 'tick' is basically a frame. If you adjust this, you may want to adjust the min and max amount spawned per tick.

[b]A note about Days[/b]
"Day" is a rough esimate that assumes every month has 30 days.

To find your day, multiply month x 30 and add how many days into the month, ie: 
 - 0 is January, 11 is December
 - June 15th would be 5 x 30 + 15 = 165
 - January 9th would be 0 x 30 + 9 = 9

Fireflies will slowly start appearing before your start day and gradually thin out after your end day.

[b]Some Information:[/b]
 - Fireflies like warmer weather. If it's too chilly out, there won't be as many, or any, fireflies.
 - They don't like the rain. If it's raining, there won't be as many, or any, fireflies.
 - Spawns will waterfall from shorelines, to trees, then to grass, with some random spawns allowed. 
 - If there are not enough ideal spawn locations, they will spawn in more random places.
 - They won't spawn very often over open water or pavement. 
 - They won't be as bright in lit areas.
 - They will try and avoid a small area around the player.

[hr][/hr]
If you're teleporting around, you may get an error if we try to update on a square that just vanished

[hr][/hr]
[b]Currently Exploring[/b]
[list][*]Depth mapping(the dream)
[*]A more user friendly day selector[/list]

[hr][/hr]
Workshop ID: 3591708775
Mod ID: JB_Fireflys
