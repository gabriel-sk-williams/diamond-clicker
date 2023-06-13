module diamond_clicker::game {
    use std::signer;
    use std::vector;

    use aptos_framework::timestamp;

    #[test_only]
    use aptos_framework::account;

    /*
    Errors
    DO NOT EDIT
    */
    const ERROR_GAME_STORE_DOES_NOT_EXIST: u64 = 0;
    const ERROR_UPGRADE_DOES_NOT_EXIST: u64 = 1;
    const ERROR_NOT_ENOUGH_DIAMONDS_TO_UPGRADE: u64 = 2;

    /*
    Const
    DO NOT EDIT
    */
    const POWERUP_NAMES: vector<vector<u8>> = vector[b"Bruh", b"Aptomingos", b"Aptos Monkeys"];
    // cost, dpm (diamonds per minute)
    const POWERUP_VALUES: vector<vector<u64>> = vector[
        vector[5, 5],
        vector[25, 30],
        vector[250, 350],
    ];

    /*
    Structs
    DO NOT EDIT
    */
    struct Upgrade has key, store, copy {
        name: vector<u8>,
        amount: u64
    }

    struct GameStore has key {
        diamonds: u64,
        upgrades: vector<Upgrade>,
        last_claimed_timestamp_seconds: u64,
    }

    /*
    Functions
    */

    public fun initialize_game(account: &signer) {

        // move_to account with new GameStore
        move_to(account, GameStore {
            diamonds: 0_u64,
            upgrades: vector::empty<Upgrade>(), // vector::empty<T>():
            last_claimed_timestamp_seconds: timestamp::now_seconds(),
        })
    }

    public entry fun click(account: &signer) acquires GameStore {
        // check if GameStore does not exist - if not, initialize_game
        let account_address = signer::address_of(account);
        if (!exists<GameStore>(account_address)) {
            initialize_game(account);
        };

        let game_store = borrow_global_mut<GameStore>(account_address);
        game_store.diamonds = game_store.diamonds + 1; // increment game_store.diamonds by +1
    }

    fun get_unclaimed_diamonds(account_address: address, current_timestamp_seconds: u64): u64 acquires GameStore {
        // loop over game_store.upgrades
        // if the powerup exists then calculate the dpm and minutes_elapsed
        // add the amount to the unclaimed_diamonds
        
        let dpm = get_diamonds_per_minute(account_address);

        let game_store = borrow_global_mut<GameStore>(account_address);
        let minutes_elapsed = (current_timestamp_seconds - game_store.last_claimed_timestamp_seconds) / 60;

        return dpm * minutes_elapsed
    }   

    fun claim(account_address: address) acquires GameStore {

        let current_timestamp = timestamp::now_seconds();
        let unclaimed_diamonds = get_unclaimed_diamonds(account_address, current_timestamp);
        let game_store = borrow_global_mut<GameStore>(account_address);

        // set game_store.diamonds to current diamonds + unclaimed_diamonds
        game_store.diamonds = game_store.diamonds + unclaimed_diamonds;

        // set last_claimed_timestamp_seconds to the current timestamp in seconds
        game_store.last_claimed_timestamp_seconds = current_timestamp;
    }

    public entry fun upgrade(account: &signer, upgrade_index: u64, upgrade_amount: u64) acquires GameStore {
        
        // check that the game store exists
        if (exists<GameStore>(signer::address_of(account))) {
            
            // claim for account address
            claim(signer::address_of(account));
            let game_store = borrow_global_mut<GameStore>(signer::address_of(account));
        
            // check the powerup_names length is greater than or equal to upgrade_index
            if (vector::length(&mut POWERUP_NAMES) >= upgrade_index) {
                let name: vector<u8> = *vector::borrow_mut(&mut POWERUP_NAMES, upgrade_index);
                let values: vector<u64> = *vector::borrow_mut(&mut POWERUP_VALUES, upgrade_index);
                let cost: u64 = *vector::borrow(&mut values, 0);
                let dpm: u64 = *vector::borrow(&mut values, 1);
                let total_upgrade_cost = upgrade_amount * cost;

                // check that the user has enough coins to make the current upgrade
                if (game_store.diamonds >= total_upgrade_cost) {

                    let amount = upgrade_amount * dpm;
                    game_store.diamonds = game_store.diamonds - total_upgrade_cost;

                    // loop through game_store.upgrades
                    let upgrade_exists = false;
                    let i = 0;
                    while (i < vector::length(&mut game_store.upgrades) && !upgrade_exists) {
                        let upgrade = vector::borrow_mut(&mut game_store.upgrades, i);

                        // if the upgrade_exists, increment by the upgrade_amount
                        if (name == upgrade.name) {
                            upgrade_exists = true;
                            upgrade.amount = upgrade.amount + amount;
                        };
                        i = i + 1;
                    };
                    
                    if (!upgrade_exists) {
                        // if upgrade does not exist, create it with the base upgrade_amount
                        let upgrade = Upgrade{ name, amount };

                        // and claim for account address
                        vector::push_back(&mut game_store.upgrades, upgrade);
                    }  
                } else {
                    abort 2
                }
            }
        } else {
            abort 0
        }
    }

    #[view]
    public fun get_diamonds(account_address: address): u64 acquires GameStore {
        
        claim(account_address);
        let game_store = borrow_global_mut<GameStore>(account_address);

        return game_store.diamonds // + unclaimed_diamonds
    }

    #[view]
    public fun get_diamonds_per_minute(account_address: address): u64 acquires GameStore {

        let game_store = borrow_global_mut<GameStore>(account_address);

        // loop over game_store.upgrades
        let dpm = 0;
        let i = 0;
        while (i < vector::length(&mut game_store.upgrades)) {
            // calculate dpm * current_upgrade.amount to get the total diamonds_per_minute
            let upgrade = vector::borrow_mut(&mut game_store.upgrades, i);
            dpm = dpm + upgrade.amount;
            i = i + 1;
        };

        return dpm // return diamonds_per_minute of all the user's powerups
    }

    #[view]
    public fun get_powerups(account_address: address): vector<Upgrade> acquires GameStore {
        let game_store = borrow_global_mut<GameStore>(account_address);
        return game_store.upgrades 
    }

    public fun test(): u64 {
        return 11_u64
    }

    /*
    Tests
    DO NOT EDIT
    */
    inline fun test_click_loop(signer: &signer, amount: u64) acquires GameStore {
        let i = 0;
        while (amount > i) {
            click(signer);
            i = i + 1;
        }
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_click_without_initialize_game(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);
        let test_one_address = signer::address_of(test_one);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        click(test_one);

        let current_game_store = borrow_global<GameStore>(test_one_address);

        assert!(current_game_store.diamonds == 1, 0);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_click_with_initialize_game(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);
        let test_one_address = signer::address_of(test_one);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        click(test_one);

        let current_game_store = borrow_global<GameStore>(test_one_address);

        assert!(current_game_store.diamonds == 1, 0);

        click(test_one);

        let current_game_store = borrow_global<GameStore>(test_one_address);

        assert!(current_game_store.diamonds == 2, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    #[expected_failure(abort_code = 0, location = diamond_clicker::game)]
    fun test_upgrade_does_not_exist(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        upgrade(test_one, 0, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    #[expected_failure(abort_code = 2, location = diamond_clicker::game)]
    fun test_upgrade_does_not_have_enough_diamonds(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        click(test_one);
        upgrade(test_one, 0, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_upgrade_one(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        test_click_loop(test_one, 5);
        upgrade(test_one, 0, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_upgrade_two(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        test_click_loop(test_one, 25);

        upgrade(test_one, 1, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_upgrade_three(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        test_click_loop(test_one, 250);

        upgrade(test_one, 2, 1);
    }
}