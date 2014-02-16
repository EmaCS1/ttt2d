-- colors
Color.innocent = Color(20, 220, 20)
Color.traitor = Color(220, 20, 20)
Color.detective = Color(50, 80, 250)
Color.spectator = Color(220, 220, 20)
Color.white = Color(220, 220, 220)

-- game states
S_WAITING = 1
S_PREPARING = 2
S_RUNNING = 3

-- player roles
R_INNOCENT = 1
R_TRAITOR = 2
R_DETECTIVE = 3
R_MIA = 4
R_SPECTATOR = 5
R_PREPARING = 6

-- ranks
RANK_ADMIN = 100
RANK_MODERATOR = 50
RANK_GUEST = 0

-- time
T_PREPARE = 15
T_GAME = 180

-- karma
Karma.base = 1000
Karma.player_base = 800
Karma.max = 1500
Karma.kick = 500
Karma.reset = 600
Karma.halflife = 0.2
Karma.regen = 5
Karma.clean = 30
Karma.speedmod = 4
Karma.hurt_reward = 0.0003
Karma.kill_reward = 40
Karma.traitor_reward = 50
Karma.hurt_penalty = 0.0015
Karma.kill_penalty = 15
Karma.vote_penalty = 100
Karma.traitor_penalty = 50
Karma.min_players = 4

-- maps
TTT.maps = {
    "ttt_suspicion",
    "ttt_trauma",
    "ttt_dust",
    "ttt_italy"
}
