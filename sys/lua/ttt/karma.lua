Karma = {}

-- {{{ Rewards
function Karma.get_hurt_reward(dmg)
    return Karma.max * dmg * Karma.hurt_reward
end

function Karma.get_kill_reward()
    return Karma.get_hurt_reward(Karma.kill_reward)
end

function Karma.give_reward(p, value)
    if #Player.table < Karma.min_players then
        return
    end

    if p.karma > 1000 then -- make it harder to reach Karma.max
        local halflife = (Karma.max-Karma.base) * Karma.halflife
        value = value * math.exponential_decay(halflife, p.karma-Karma.base)
    end

    p.karma = math.min(p.karma+value, Karma.max)
end

function Karma.give_points(p, value)
    if #Player.table < Karma.min_players then
        return
    end

    p.points = p.points + math.max(value, 0)
end
-- }}}

-- {{{ Penalties
function Karma.get_penalty_multiplier(karma)
    local halflife = Karma.max * Karma.halflife
    return math.exponential_decay(halflife, Karma.base-karma)
end

function Karma.get_hurt_penalty(victim_karma, dmg)
    if victim_karma < 1000 then
        dmg = dmg * Karma.get_penalty_multiplier(victim_karma)
    end
    return victim_karma * dmg * Karma.hurt_penalty
end

function Karma.get_kill_penalty(victim_karma)
    return Karma.get_hurt_penalty(victim_karma, Karma.kill_penalty)
end

function Karma.give_penalty(p, value)
    if #Player.table < Karma.min_players then
        return
    end
    p.karma = math.max(p.karma-value, 0)
end
-- }}}

-- {{{ Calculations
function Karma.hurt(attacker, victim, dmg)
    if attacker == victim then return end

    if not attacker:is_traitor() and victim:is_traitor() then
        local reward = Karma.get_hurt_reward(dmg)
        Karma.give_reward(attacker, reward)

    elseif attacker:is_traitor() == victim:is_traitor() then
        local penalty = Karma.get_hurt_penalty(victim.karma, dmg)
        Karma.give_penalty(attacker, penalty)
        attacker.karma_clean = false
    end
end

function Karma.killed(attacker, victim)
    if attacker == victim then return end

    if not attacker:is_traitor() and victim:is_traitor() then
        local reward = Karma.get_kill_reward()

        Karma.give_reward(attacker, reward)
        Karma.give_points(attacker, (attacker.karma/Karma.base))

    elseif attacker:is_traitor() == victim:is_traitor() then
        local penalty = Karma.get_kill_penalty(victim.karma)

        Karma.give_penalty(attacker, penalty)
        attacker.karma_clean = false
    end
end

function Karma.round_end(winner)
    Player.each(function(p)
        if p:is_traitor() then
            if p.role == winner then
                Karma.give_reward(p, Karma.traitor_reward)
            else
                Karma.give_penalty(p, Karma.traitor_penalty)
            end
        end

        if p.karma < Karma.base then
            Karma.give_reward(p, Karma.regen + (p.karma_clean and Karma.clean or 0))
        end

        if p.karma < Karma.kick then
            if p.usgn == 0 then
                p:banip(5, "Your karma went too low. Banned for 5 minutes!")
            else
                p:banusgn(5, "Your karma went too low. Banned for 5 minutes!")
            end
        end

        p.score = p.karma
    end)
end
-- }}}

-- {{{ Hooks
Hook("spawn", function(p)
    Timer(1, function()
        if not p:is_preparing() then
            return
        end

        p.score = p.karma
        p.karma_clean = true

        if p.karma < 1000 then
            p.damagefactor = Karma.get_penalty_multiplier(p.karma)
        else
            p.damagefactor = 1
        end

        p.damagefactor = math.max(p.damagefactor, 0.1)
        p.speedmod = (p.karma-Karma.base)/(Karma.base/Karma.speedmod)
    end)
end, -100)

Hook("vote", function(p)
    Karma.give_penalty(p, Karma.vote_penalty)
end)

Hook("join", function(p)
    Timer(1, function()
        p.damagefactor = 1
        p.score = p.karma
    end)
end)
-- }}}

