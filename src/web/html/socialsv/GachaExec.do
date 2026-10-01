<?php
require_once "../tools/dec_enc.php";
require_once "../tools/jsonTools.php";
require_once "../tools/devilTools.php";

function FusionExec() {
    // Get the query parameter
    $params = StringToJsonObject(Decrypt($_GET['param']));

    $dvl2add = makeDevilAccurate(getRandomValue("../tools/ids.txt"), makeUniq(11), true);

    addToJson("../saves/players/0/devils.json", "devils", [$dvl2add]);

    $data2Ret = [
    "transaction_id"=> "33-03A-0B3E4C",
    "server_time"=> 1740168406558,
    "update_partner_infos"=> [
        [
            "vit"=> 176,
            "devil_id"=> 10550,
            "soul_injection_vit"=> 0,
            "aptitudes"=> [
                [
                    "type"=> 8,
                    "value"=> 0
                ],
                [
                    "type"=> 7,
                    "value"=> 0
                ],
                [
                    "type"=> 11,
                    "value"=> 0
                ],
                [
                    "type"=> 4,
                    "value"=> 0
                ],
                [
                    "type"=> 2,
                    "value"=> 0
                ],
                [
                    "type"=> 5,
                    "value"=> 0
                ],
                [
                    "type"=> 9,
                    "value"=> 40
                ],
                [
                    "type"=> 3,
                    "value"=> 0
                ],
                [
                    "type"=> 6,
                    "value"=> 40
                ],
                [
                    "type"=> 1,
                    "value"=> 0
                ],
                [
                    "type"=> 10,
                    "value"=> 40
                ]
            ],
            "hp"=> 128,
            "magical_defense"=> 51,
            "str"=> 63,
            "intimacy"=> 1,
            "physical_defense"=> 41,
            "magical_attack"=> 26,
            "mag"=> 176,
            "partner_skill"=> [
                [
                    "lv"=> 0,
                    "id"=> 710038
                ],
                [
                    "lv"=> 0,
                    "id"=> 0
                ],
                [
                    "lv"=> 0,
                    "id"=> 0
                ]
            ],
            "physical_attack"=> 10,
            "soul_injection_str"=> 0,
            "soul_injection_mag"=> 0,
            "skill_change_gage"=> 0
        ]
    ],
    "update_devils"=> [
        [
            "agi"=> 19,
            "exceed_info"=> [
                "opened_num"=> 0
            ],
            "hpmx"=> 96,
            "luk"=> 17,
            "devicon_power"=> 456,
            "hp"=> 96,
            "recommend_type"=> 1,
            "lv"=> 1,
            "additional_skl"=> [],
            "mdef"=> 86,
            "limitbreak"=> [
                "effect"=> [],
                "num"=> 100,
                "open"=> []
            ],
            "is_awk"=> false,
            "dr"=> 0,
            "ai_auto_type"=> 1,
            "mag"=> 19,
            "limitbreak_skl"=> [],
            "arc"=> 4,
            "wk"=> 72,
            "skl"=> [
                [
                    "lv"=> 1,
                    "id"=> 2013
                ],
                [
                    "lv"=> 1,
                    "id"=> 101404
                ],
                [
                    "lv"=> 1,
                    "id"=> 1138
                ],
                [
                    "lv"=> 1,
                    "id"=> 101103
                ],
                [
                    "lv"=> 1,
                    "id"=> 103010
                ],
                [
                    "lv"=> 0,
                    "id"=> 0
                ],
                [
                    "lv"=> 0,
                    "id"=> 0
                ]
            ],
            "id"=> $dvl2add['id'],
            "patk"=> 70,
            "exp"=> 0,
            "vit"=> 19,
            "is_released_learn_only_skill"=> false,
            "st"=> 0,
            "pdef"=> 80,
            "mp"=> 10,
            "mgtm_effs"=> [],
            "lock_ex_skl"=> [
                true
            ],
            "is_new"=> true,
            "mgtms"=> [],
            "str"=> 7,
            "av"=> 48,
            "spt"=> 0,
            "uniq"=> 30480173975,
            "matk"=> 95,
            "mpmx"=> 10,
            "rp"=> 0,
            "rarity"=> 3,
            "contents_type"=> 0
        ]
    ],
    "res_code"=> 0,
    "client_wait"=> 0,
    "devils"=> [
        [
            "agi"=> 19,
            "exceed_info"=> [
                "opened_num"=> 0
            ],
            "hpmx"=> 96,
            "luk"=> 17,
            "devicon_power"=> 456,
            "greeting"=> "Hello there",
            "hp"=> 96,
            "recommend_type"=> 1,
            "lv"=> 1,
            "additional_skl"=> [],
            "mdef"=> 86,
            "is_awk"=> false,
            "dr"=> 0,
            "ai_auto_type"=> 1,
            "mag"=> 19,
            "arc"=> $dvl2add['arc'],
            "wk"=> 72,
            "skl"=> $dvl2add['skl'],
            "id"=> $dvl2add['id'],
            "patk"=> 70,
            "exp"=> 0,
            "is_own"=> true,
            "vit"=> 19,
            "is_released_learn_only_skill"=> false,
            "st"=> 0,
            "pdef"=> 80,
            "mp"=> 10,
            "mgtm_effs"=> [],
            "is_new"=> true,
            "premium_skill_idx"=> 4,
            "mgtms"=> [],
            "str"=> 7,
            "av"=> 48,
            "spt"=> 0,
            "uniq"=> 30480173975,
            "matk"=> 95,
            "premium_skill_idx2"=> -1,
            "mpmx"=> 10,
            "exceed_piece_num"=> 1,
            "rp"=> 0,
            "rarity"=> 3,
            "contents_type"=> 0,
            "effect_id"=> 0
        ]
    ],
    "bonus_list"=> [
        [
            "num"=> 1,
            "is_bonus"=> false,
            "id"=> 10210,
            "type"=> 2
        ]
    ],
    "usr"=> [
        "gb_exchange_ticket"=> 0,
        "qst_skp_ticket"=> 40,
        "dp_itm"=> 0,
        "mc"=> 7980348,
        "pp_itm"=> 0,
        "mg"=> 16616129,
        "fame"=> 932,
        "cp"=> 9184,
        "ap_itm"=> 27,
        "pvppt"=> 60
    ],
    "tm"=> "141"
];

    echo json_encode($data2Ret);
}

// Call the function when the request is a GET request
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    FusionExec();
}
?>
