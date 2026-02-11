using HTTP, JSON, Dates, Statistics

# --- KONFIG Wichtig ---
const API_KEY = "" # Replace this with your key from: developer.hypixel.net
const SCAN_INTERVAL = 60            # Seconds between scans
const MAX_HISTORY = 20              # Number of saved datapoints for the integral

# Datenstructure
mutable struct ItemState
    price::Float64
    volume::Float64
    timestamp::DateTime
end

# Savings for History
history_db = Dict{String, Vector{ItemState}}()


# 1. path-Integral
function wegintegral(history)
    if length(history) < 2 return 0.0 end
    integral = 0.0
    for i in 2:length(history)
        dP = history[i].price - history[i-1].price
        Mitt_V = (history[i].volume + history[i-1].volume) / 2
        integral += Mitt_V * dP # Work = Force * Path
    end
    return integral
end

# 2. Crafting
# Example: 160 Enchanted Items -> 1 Enchanted Block
function check_crafting_vortex(products, base_id, block_id, ratio=160)
    try
        buy_raw = products[base_id]["quick_status"]["sellPrice"] # Price for Insta-Buy
        sell_block = products[block_id]["quick_status"]["buyPrice"] # Price for Insta-Buy
        return sell_block - (buy_raw * ratio)
    catch
        return 0.0
    end
end

# 3. Divergenz-Module (Market-Flow)
function calculate_market_divergence(item_status)
    # Diff Buy- and Sellvolume /Wocje
    return item_status["sellMovingWeek"] - item_status["buyMovingWeek"]
end

# --- HAUPTPROGRAMM ---

function run_bazaar_analyzer()
    println("---  Skyblock Bazaar Analyzer started ---")
    
    while true
        try
            # get Data
            response = HTTP.get("https://api.hypixel.net/skyblock/bazaar")
            data = JSON.parse(String(response.body))
            products = data["products"]
            
            println("\n[$(Dates.format(now(), "HH:mm:ss"))] Scan läuft...")
            
            # Analyze for every item
            for (id, item) in products
                status = item["quick_status"]
                current_price = status["buyPrice"]
                current_volume = status["buyVolume"]
                
                # ipdate History
                if !haskey(history_db, id) history_db[id] = [] end
                push!(history_db[id], ItemState(current_price, current_volume, now()))
                if length(history_db[id]) > MAX_HISTORY popfirst!(history_db[id]) end
                
                E = wegintegral(history_db[id])
                divergence = calculate_market_divergence(status)
                
                # only signals if significant
                if E > 1_000_000 
                    println("MOMENTUM ALERT: $id surging. Energy $(round(E/1e6, digits=2))M")
                end
                
                if divergence < -500_000 # Hohe Nachfrage, wenig Angebot
                    println("DIVERGENCE: $id supply is tightening! (Div: $(round(divergence/1e6, digits=2))M)")
                end
            end
            
            # Arbitrage Example-Check
            slime_profit = check_crafting_vortex(products, "ENCHANTED_SLIME_BALL", "ENCHANTED_SLIME_BLOCK")
            if slime_profit > 0
                println("💰 ARBITRAGE: Slime-Block Flip gets you $slime_profit Coins!")
            end

        catch e
            println("Error catching Data: $e")
        end
        
        sleep(SCAN_INTERVAL)
    end
end

# Start
run_bazaar_analyzer()