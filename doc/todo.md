# To-Dos

Open items only.

## Animals: hunger
Checked: animals **can** eat (`animal_brain.gd`): ducks, geese, pigeons and dogs forage
(`state == "forage"`, `needs.eat(45)`), others go to the food bowl at the kiosk, and they take
treats from visitors and the duck-feeding minigame. Since they are also rested at midnight
(`Game.rest_animals_at_midnight`), nothing needs to change. Only revisit if animals are seen
starving with no food reachable (e.g. in the Nordwald).
