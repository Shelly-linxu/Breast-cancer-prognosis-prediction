window.GBCS_MODEL = 
{
  "model_name": "GBCS diagnosis-time clinical Cox model",
  "version": "2026-07-18",
  "endpoint": "Five-year all-cause mortality",
  "horizon_months": 60,
  "required_predictors": ["age", "stage", "er", "pr", "her2", "ki67"],
  "allowed_levels": {
    "stage": ["I", "II", "III", "IV"],
    "er": ["Negative", "Positive"],
    "pr": ["Negative", "Positive"],
    "her2": ["Negative", "Equivocal", "Positive"],
    "ki67": ["<14%", ">=14%"]
  },
  "age_knots": [43, 52],
  "age_boundaries": [19, 97],
  "spline_intervals": [
    {
      "left": 19,
      "right": 43,
      "coefficients": [
        [0, 0, 0],
        [-0.017977936632415488, 0.039551460591314071, -0.021573523958898583],
        [1.0842021724855044e-19, -1.0842021724855044e-19, -6.5052130349130266e-19],
        [2.7059772583140041e-05, -2.3918964070372481e-05, 1.3046707674748645e-05]
      ]
    },
    {
      "left": 43,
      "right": 52,
      "coefficients": [
        [-0.057396182988643733, 0.61857929488270846, -0.33740688811784103],
        [0.028781350391250533, -0.001780509322289639, 0.00097118690306709004],
        [0.001948303625986082, -0.0017221654130668129, 0.00093936295258189803],
        [-0.00012528121396701301, 7.6891928790809758e-05, -2.115708066645915e-05]
      ]
    },
    {
      "left": 52,
      "right": 97,
      "coefficients": [
        [0.26811855925553124, 0.51911352861219018, -0.2680013186369522],
        [0.033407480665015872, -0.014094748061325499, 0.012738549447591679],
        [-0.0014342891511232676, 0.00035391666428505217, 0.0003681217745875033],
        [1.0624364082394585e-05, -2.6216049206300219e-06, -2.7268279599074389e-06]
      ]
    }
  ],
  "components": [
    {
      "coefficients": [
        0.030724792304914702,
        0.8654439167402157,
        2.5691969396954915,
        0.45610911656496367,
        1.6440332368518984,
        2.8029352347180989,
        -0.18612855314112445,
        -0.31279987771606554,
        -0.060426825948796288,
        -0.14945118642746907,
        0.47903624959262592
      ],
      "coefficient_names": ["ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))1", "ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))2", "ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))3", "stageII", "stageIII", "stageIV", "erPositive", "prPositive", "her2Equivocal", "her2Positive", "ki67>=14%"],
      "baseline_hazard_60": 0.036575708296800076
    },
    {
      "coefficients": [
        0.046828463915723262,
        1.2085879078834665,
        2.7798790598019334,
        0.48852728069210255,
        1.7023439807719793,
        2.7831191183023143,
        -0.15783589854428876,
        -0.35108713928525126,
        -0.032503467280159869,
        -0.22546175478833042,
        0.53197535138833052
      ],
      "coefficient_names": ["ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))1", "ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))2", "ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))3", "stageII", "stageIII", "stageIV", "erPositive", "prPositive", "her2Equivocal", "her2Positive", "ki67>=14%"],
      "baseline_hazard_60": 0.030366071877650329
    },
    {
      "coefficients": [
        0.022260104753770125,
        0.79929647817778626,
        2.4536584551582101,
        0.42750469711927197,
        1.588498244506825,
        2.8141005635705434,
        -0.17052640888322673,
        -0.3618338979911534,
        -0.070784279918900128,
        -0.28214604686087719,
        0.58517941944785035
      ],
      "coefficient_names": ["ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))1", "ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))2", "ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))3", "stageII", "stageIII", "stageIV", "erPositive", "prPositive", "her2Equivocal", "her2Positive", "ki67>=14%"],
      "baseline_hazard_60": 0.036298036302877007
    },
    {
      "coefficients": [
        0.070492262839498332,
        1.2219205971772857,
        2.7476294769268441,
        0.50556177083055298,
        1.7148725685563202,
        2.8090095746795312,
        -0.15776235263937866,
        -0.29839575963485604,
        -0.070039881548329228,
        -0.16251582950485904,
        0.48723423109836905
      ],
      "coefficient_names": ["ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))1", "ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))2", "ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))3", "stageII", "stageIII", "stageIV", "erPositive", "prPositive", "her2Equivocal", "her2Positive", "ki67>=14%"],
      "baseline_hazard_60": 0.029295180592519034
    },
    {
      "coefficients": [
        0.13359597179246208,
        0.55699126254068376,
        2.2286935666872298,
        0.41962850695876996,
        1.6095362925000289,
        2.8042614689629897,
        -0.19687549800140502,
        -0.27058970238043434,
        -0.12888240300524217,
        -0.13939314959519372,
        0.38583675264600553
      ],
      "coefficient_names": ["ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))1", "ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))2", "ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))3", "stageII", "stageIII", "stageIV", "erPositive", "prPositive", "her2Equivocal", "her2Positive", "ki67>=14%"],
      "baseline_hazard_60": 0.043203178112738105
    },
    {
      "coefficients": [
        -0.012214809360449379,
        0.81993335080701124,
        2.6508253537176505,
        0.46119857880681531,
        1.6287817034214336,
        2.7979523904333328,
        -0.11083982043817006,
        -0.31776029511131276,
        -0.062775643997886169,
        -0.19253422438907122,
        0.46792283277834368
      ],
      "coefficient_names": ["ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))1", "ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))2", "ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))3", "stageII", "stageIII", "stageIV", "erPositive", "prPositive", "her2Equivocal", "her2Positive", "ki67>=14%"],
      "baseline_hazard_60": 0.038047056727756351
    },
    {
      "coefficients": [
        0.060319508398487112,
        0.79793566885330147,
        2.4906132398400471,
        0.41195165558791758,
        1.5577438747281671,
        2.7560759120731895,
        -0.17857063401963358,
        -0.3395575421866539,
        -0.047637633867114185,
        -0.19078017714005108,
        0.4918717860309621
      ],
      "coefficient_names": ["ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))1", "ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))2", "ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))3", "stageII", "stageIII", "stageIV", "erPositive", "prPositive", "her2Equivocal", "her2Positive", "ki67>=14%"],
      "baseline_hazard_60": 0.039358868041807028
    },
    {
      "coefficients": [
        0.015978121775671244,
        0.99299510549598735,
        2.7242633731161621,
        0.50027895212194917,
        1.6923155979898237,
        2.831614707972387,
        -0.15100172573863968,
        -0.35135954417496978,
        -0.0517441629832067,
        -0.18393553170978452,
        0.46405200258804097
      ],
      "coefficient_names": ["ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))1", "ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))2", "ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))3", "stageII", "stageIII", "stageIV", "erPositive", "prPositive", "her2Equivocal", "her2Positive", "ki67>=14%"],
      "baseline_hazard_60": 0.034784162131301019
    },
    {
      "coefficients": [
        0.080094572843683778,
        0.86456059856226453,
        2.4507971476654253,
        0.43054668892131659,
        1.5385443879522995,
        2.6516070749559395,
        -0.16847222945725457,
        -0.36801350781210423,
        -0.077640609893649126,
        -0.20325423327215661,
        0.52925495128845501
      ],
      "coefficient_names": ["ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))1", "ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))2", "ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))3", "stageII", "stageIII", "stageIV", "erPositive", "prPositive", "her2Equivocal", "her2Positive", "ki67>=14%"],
      "baseline_hazard_60": 0.03696990858435998
    },
    {
      "coefficients": [
        0.042090657166767846,
        0.75211007741413893,
        2.4660767621809425,
        0.40332903628211725,
        1.5969313132062677,
        2.5688875337983443,
        -0.13621724444276448,
        -0.3139700873662658,
        -0.066541763300266746,
        -0.18621159835358483,
        0.61590365565647132
      ],
      "coefficient_names": ["ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))1", "ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))2", "ns(age, knots = c(43, 52), Boundary.knots = c(19, 97))3", "stageII", "stageIII", "stageIV", "erPositive", "prPositive", "her2Equivocal", "her2Positive", "ki67>=14%"],
      "baseline_hazard_60": 0.035083557185323917
    }
  ]
}
;
