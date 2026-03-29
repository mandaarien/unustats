"""
Applet: E-Scooter Charging Stats (Home Assistant)
Summary: Charging Stats for Home Assistant
Description: Show (UNU/NIU) Electric Scooter Charger Stats from Home Assistant on your Tidbyt. Needs Home Assistant with a Power Outlet Sensor and some Helper Entities to track Yearly Energy, Total Charges and Cost. Needs TidbytAssistant from HACS (@savdagod) and TidbytAssistant from HACS (@savdagod) to work.
Author: mandaarien
"""

"""
Helper Entity Example Setup (Home Assistant):

# ==========================
-----> HA Helper <-----
# ==========================
Setup a new Helper Entity -> Counter -> create: E.g. counter.unu_charging_cycles

# ==========================
Setup a new Helper Entity -> Boolean Input -> create: E.g. input_boolean.unu_charging_active 


# ==========================
------> HA Automations YAMLs (for Charging Cylces Counter) <-----
# ==========================
alias: UNU Charger - Charging Started
triggers:
  - entity_id: sensor.smart_switch_xxxxxxxxx_power     <----- Put name of Smartplug/Switch here as Power source
    above: 10
    trigger: numeric_state
conditions:
  - condition: state
    entity_id: input_boolean.unu_charging_active
    state: "off"
actions:
  - entity_id: input_boolean.unu_charging_active
    action: input_boolean.turn_on

# ==========================
alias: UNU Charger - Charging Ended
triggers:
  - entity_id: sensor.smart_switch_xxxxxxxxx_power     <----- Put name of Smartplug/Switch here as Power source
    below: 10
    for:
      minutes: 1
    trigger: numeric_state
conditions:
  - condition: state
    entity_id: input_boolean.unu_charging_active
    state: "on"
actions:
  - entity_id: input_boolean.unu_charging_active
    action: input_boolean.turn_off
  - entity_id: counter.unu_charging_cycles
    action: counter.increment


# ==========================
-----> configuration.yaml <-----
# ==========================
sensor:
  - platform: integration
    name: unu_charger_live_energy
    source: sensor.smart_switch_xxxxxxxxx_power     <----- Put name of Smartplug/Switch here as Power source
    unit_prefix: k
    unit_time: h
    round: 4
    method: trapezoidal
  - platform: integration
    name: unu_charger_live_energy
    source: sensor.smart_switch_xxxxxxxxx_power     <----- Put name of Smartplug/Switch here as Power source
    unit_prefix: k
    unit_time: h
    round: 4
    method: trapezoidal

# ==========================
-----> templates.yaml <-----
# ==========================
sensor:
  - name: "UNU Charger Live Cost"
    unit_of_measurement: "€"
    state: >
      {% set energy = states('sensor.unu_charger_live_energy') | float(0) %}
      {% set price = states('sensor.octopus_xxxxxxxxx_electricity_price') | float(0) %} # or choose own kwh price source or fixed price
      {{ "%.4f" | format(energy * price) }}
"""

load("animation.star", "animation")
load("encoding/base64.star", "base64")
load("render.star", "render")
load("math.star", "math")
load("http.star", "http")
load("encoding/json.star", "json")
load("time.star", "time")
load("schema.star", "schema")

# ==========================
# Image Assets
# ==========================
ICON_UNU = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAYAAACinX6EAAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAALEwAACxMBAJqcGAAAAytJREFUaAXtlk+IzVEUx+c9jH+NP1mIEmPBWEiRkhSFkshCyUIWUyZlRykUZqFZTSmyo2mabA0LxMJC0VCaYaEmTZ4hfwZFhsHM/HzOzzmv+37v935/Xnbuqe87557zPefe37n397uvocGL74DvgO+A74DvgO+A78B/2oFC1ucOgqADrvAvFQqFV0l5cLcSXwXvYpRHbBq+/WAnWALmg+fgAegi5zO6LPCnM2hXRyfxkXIwxoC/F/dieBdiwvW7KDwORDakVYFTCplBsNHl4lsOnmosTn3EuSuS0+QQW9xYnA33u/BHR0tr4+JR39SoI2Gc+bRQY57WmWX1WNMKbNnlBeA3uAb6wC+wBsipkFgv3N3s4C3sXEJekYSZklQsNs7OlZxGpnieE/AFvsg2q4t9P/QEwTB6tflN41sI+pTzEt0oMXTmEwC3qPmi1lntJC0dyypBViK8itPCYuSBN2l+K7v7LFoL33t8e8A3sBTsAyJ55v2bkeM3TwNylK2i2m584EHvVkXVQewd5h0drq/FS/BXND6BVw7lacCkZmWZJMpp0tyh8sy1jRcaalbtnoBo3dpVMkbyNOCH1rSHiZ2C4y4fVvv4WY5cfSLy8UuTr0qwtY0ztibMSEme68RtbsdVbdok1ZFqz6C6llWHKjzytbe6rzVit408TFYJd5vX4icJbzVpZUqyXZPByHDvWAo3DNtCs3AfKamVXU7Ka1VeicWX1K67AZr/RPUh5k56DdqUNzA60f9G7X+jmLgFTACRLhBeU251fAeAXZdHLYbvNBC5ab5aGs7JkOlwGW9Xn6hOYK9UWIZxARwDJrYJtaapz0/1UzYDegicA23gDHgITO5hlBeJ3a6BG2kzw7MGVPwRwn9ea4gaBB3gMDgL+oHJdYykU5K2hOQ4xY+DMZstRnfjm+NWYXxCeT2uP852uLfdOP4pQB56EsSJ+C+DcuPd/Fp2XZ1ikmYKHgSbwSLwCQyAbt57+XtbIfDlL+4RcJW4XXMVHBvA3YK9AwzCvWJ+08TlQydHXP4nyI0kN8tj0APfvlMMvfgO+A74DvgO+A74DvgO+A4kduAPrMtMuUn2i9QAAAAASUVORK5CYII=
""")
ICON_NIU = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAYAAACinX6EAAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAALEwAACxMBAJqcGAAAAspJREFUaAXtlt+LTGEYx/dIflyo2fxISGtbSqkZriQXg2uiLCntP6A2CZv2Zm62tEhu3FB74VKhlDu2uJrWFiVKspsbuUEJF+L4PGefdzznOHPmtc1g2vep7zy/vu/7vM9z5sy8PT1BwgTCBMIEwgTCBMIEwgQKJhDHcRmsLqCkUnAroJQKdqtDI0eByHufHuAdT9hx/Ba9wmfNv+QsKipOA/IUrygnwl9SxNfcKtVr0Wc9+P8vhYbHgJNxn5NCXgpmdNEXdH+zdeSGwFVwDZwAua8N8WEwavfB3wxkbdnGxSYmr6DkBrI5b5/F/eA7cDKDMekJaA25nS1KpgSmG4xfxhvMSg4/Ydg4gZouq9m42EW5LHdxNmD8k9j2FenDF/ypHORAW6MoemEWylB2gI/gOvgMhsAmcAt+Gf4n7I6LbTBb7AGBOBuch/+ENbNuHc1tw64CabpKo2dADVsGMgtkCIPgr0jTAXCoO0DyOzMnOUQ8V+A9NtyHStqO/mrie9SeIv7UxbHl23BD/S0u3mnddACuMAerY084H10xdsPkyS7HkV9+J8POyOiVGd+6P9RZZoOdtFsOQIufQ8sTEjlFsxvnzNTnCN4GjUzYp5titd9Zl7Pleo21fIW9BkAz79jwsm4ql5vzaieKgfRhuP98GdTpJNHZj2ndfpD6a1wpbBnIYfXld6xQvAagO4yhX6t9jEK7zc5yWZJXQOQCA/O6Nc7R5/dJjbusnAIl8JzzXBJgP9NYHc4j7PYJBfYCJ8kTwKm6APoViIoqkh9RvjSQEuKjmrtoE8SS+4iNiU28F9R1jVUS683y2+Kz8X1T6Sb2S+Pva1UErlyC5BLz24+pyaVud8QPgNy/RuJyRT8CZE9BLq/VubzzFBgA30BW7nlv0u1EOt8PPpgJTGLLu7iwhKZ3AfeXs7CaD92GCYQJhAmECYQJdP8EfgKTtCskVsxp8AAAAABJRU5ErkJggg==
""")
ICON_GENERIC = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAYAAACinX6EAAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAALEwAACxMBAJqcGAAAAaVJREFUaAXtVjFSwzAQTBiKlPCD8APo0pGOlo6WL9DR2ZRUyU9oKaGCDn6QJ1BSmr1ByhwaXywuJ2Ebacaj00l3t7uWNJpMSisKFAWKAkWBv1egaZoKX9g+UyM7SFkgZMPGVWTdGWIeItf2bxkjHJqdAvCAlMwOUyZH7lrI/yz4s7un2StGFqQd4JdO0bxt3Se5A4D9iG/hFrvzCFgTlfKZCwCycxT7kArG+JFjxda9M7v/ZsvfbnOJOwCLT3lAasamOwDA5waA33yOlGff1zAVAEmvfGJNT3+exZ0xO5lpLcBMixTcNyx2DfuCBGEt+auQ1deZAFsxwFpzg8BLKViHTI6y3gFypcgZnPsTLOXP32OMax8OYRbetuhNHxgAtwSocwesdv0r+sfA94QxfT8ayN+Rg/6+m1jDdxP4buG7d/P97YgEa/QwWrHxchdyto7MX8Xuypt1DsCvAyLbYReQfWK7cmedB5Fqy/rbiL7J94nNSrIUKwroFXDH40WfYeCRwf0wbiFAdhEQlob/T4iBb2QdfL4jdBlGEkVCjIRKoTFIBb4AnMpXOVeTJlcAAAAASUVORK5CYII=
""")
ICON_CHARGER_ON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABAElEQVR4AaSRPdIBQRCGu7e+4AuFQldwA1VWzgmYGxAJNZmIG/g5gdwqG5K5ARmhTGRbT5VRM2tmVdFVXdN/7zM9NRH8aB8BtRlV6jNqhu75CPiL8AgRTr4CxMvRVgsjxJ0+fR7cQFYvA3NNi/ie7fXp8yBAVj8bAQKkEDAvIJ6T8+a1okNAD28AWf0fELu2IF4M2bj0S3bvDSCr3+wBJ864lyq62jUH0FgM+3YzFx8SRdNczX3Cuj0YJ+0BameAE1gmtaqVvkJng1dVAgSowNNELOkzyR1BgJnDjL03m34xgHla9IUa4gXIV5U541bSoZ4eKnIvIFV02ShaFQlN7wEAAP//ABS2DAAAAAZJREFUAwADMEgh9HX0QwAAAABJRU5ErkJggg==
""")
ICON_CHARGER_OFF = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAA+klEQVR4AaRSOxKCMBAlVJSWllzBG3gEvYk0wEBDxa+Ro3gDLbXjBtppaWcF+JYhTBJCmFEmj93sy3vZBGzrz2fRIMsyN03T3dw+iwaMsbtt28efDPI8Pw/C6xAnYbaDsizXWL0FrLZtbxR1mDWA6MkFXdddeK5GrQFal84cx3GtCvl8YpAkiQPyAIwDhh0H+NVIIJkYOI7zQV07cCwPBm+RlAyKoghEUsnrKIoqpWZJBkEQFGEYMgIWPoBxoLYZJ0IiGQh1Sl16ESBmFHUwGfTrm6bR7tyTeC0ZVKZPCL18B1Qg0F+IG9+jdY/mJmg78H3/hRs/mYSc+wIAAP//zQXHxwAAAAZJREFUAwAM7kshACyv7AAAAABJRU5ErkJggg==
""")
COUNTER = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAA+UlEQVR4AcyRMRKCMBBFCcwwsfQYdpaWHkFPYOsRoDINmJzGI8gNtPQYllTE/6PJTAYQZ2h09rG77PrJhzSZ+ftjAaWU1Fpb7xD1DZx97/OoBSnlCUsP4GPdtq3xjc+RQFVV67qudwQLhRCiYU3QJ3meb1kbYzbsSSSQZdk1TdML4dBae2RN2DOTruskexIJFEWxBAJHXXDImqC+A82alGXZoHcRCbg7uPzqH6tJEFB46/RHMBj1/5lj5R1BgE+lP8LRmH/MD5x7ggC8lWDSP3b2/s/MQYAN4UmQJ78/dlz0BPAEnmTlprigF3g/T5SD0RMY3Ppyc7bACwAA//98IFGbAAAABklEQVQDAIHObiHPoVcNAAAAAElFTkSuQmCC
""")

# ============================
# Default Config Values
# ============================
HOURS = 24  # Default Number of hours for the power graph

COLORS = {
    "unu_red": "#fe544b",
    "unu_green": "#44a181",
    "black": "#000000",
    "text_primary": "#ffffff",
    "text_secondary": "#bbbbbb",
}

# ============================
# Configurable Fields in UI
# ============================
def get_schema():

    options = [
        schema.Option(
            display = "Generic",
            value = "generic",
        ),
        schema.Option(
            display = "UNU",
            value = "unu",
        ),
        schema.Option(
            display = "NIU",
            value = "niu",
        ),
    ]

    return schema.Schema(
        version="1",
        fields=[
            schema.Dropdown(
                id = "brand_id",
                name = "Brand Logo",
                desc = "Show Logo of E-Scooter Brand.",
                icon = "brush",
                default = options[0].value,
                options = options,
            ),
            schema.Text(
                id="server_address_input",
                name="HA Server Address",
                desc="Server Address or IP with Port.",
                icon="server",
                default="http://yourhomeassistant:8123",
            ),
            schema.Text(
                id="server_api_key",
                name="API Token",
                desc="Input longlived Home Assistant API Token.",
                icon="key",
            ),
            schema.Text(
                id="entity_power_outlet",
                name="Entity Power Outlet",
                desc="Name of used Powerplug/Outlet Entity for Powertracking of the Charger.",
                icon="plug",
                default="sensor.smart_switch_xxxxxxxxx_power",
            ),
            # schema.Text(
            #     id="entity_charging_boolean",
            #     name="Entity Charging Boolean Helper",
            #     desc="Entity ID (e.g. input_boolean.charging).",
            #     icon="bolt",
            #     default="input_boolean.unu_charging_active",
            # ),
            schema.Text(
                id="entity_total_energy",
                name="Entity Total Energy Helper",
                desc="Name of used Helper Entity for Tracking of Total Energy yearly.",
                icon="calculator",
                default="sensor.unu_charger_total_energy",
            ),
            schema.Text(
                id="entity_total_charges_count",
                name="Entity Total Charges Count Helper",
                desc="Name of used Helper Entity for Tracking of Total Charges Count.",
                icon="9",
                default="counter.unu_charging_cycles",
            ),
            schema.Text(
                id="entity_total_cost",
                name="Entity Total Cost Helper",
                desc="Name of used Helper Entity for Tracking of Total Cost.",
                icon="moneyBill",
                default="sensor.unu_charger_live_cost",
            ),
            schema.Text(
                id="hours_power_graph",
                name="Hours Power Graph",
                desc="Number of hours for the power graph to plot.",
                icon="chartLine",
                default="24",
            ),
        ],
    )


def main(config):
    brand_id = config.get("brand_id", "generic")
    server_address = config.get(
        "server_address_input", "http://192.168.1.30:8123")
    token = config.get("server_api_key", "")

    entity_power_outlet = config.get("entity_power_outlet")
    entity_charging_boolean = config.get("entity_charging_boolean") # not used anymore
    entity_total_energy = config.get("entity_total_energy")
    entity_total_charges_count = config.get("entity_total_charges_count")
    entity_total_cost = config.get("entity_total_cost")
    hours = to_int_or_default(config.get("hours_power_graph", "24"), HOURS)

# ======================================
# Render Main
# ======================================

    # Display sequence steps
    slides = []
    slides.extend([

        # 0 Intro Logo short blink slide
        animation.Transformation(
            duration=25,
            delay=0,
            direction="normal",
            fill_mode="forwards",
            child=render_intro_logo(brand_id),
            keyframes=[
                animation.Keyframe(
                    percentage=0.0,
                    transforms=[animation.Translate(0, 0)],
                    curve="linear",
                ),
                animation.Keyframe(
                    percentage=0.7,
                    transforms=[animation.Translate(0, 0)],
                ),
                animation.Keyframe(
                    percentage=0.73,
                    transforms=[animation.Translate(-256, 0)],
                ),
                animation.Keyframe(
                    percentage=1.0,
                    transforms=[animation.Translate(-256, 0)],
                ),
            ],
        ),

        # 1 Current Charging and Weekly Power Graph and total Charges Count slide
        animation.Transformation(
            duration=175,
            delay=15,
            direction="normal",
            fill_mode="forwards",
            child=render_currtent_charging_info(
                server_address, token, hours,
                entity_power_outlet,
                entity_charging_boolean, entity_total_charges_count
            ),
            keyframes=[
                animation.Keyframe(
                    percentage=0.0,
                    transforms=[animation.Translate(64, 0)],
                    curve="linear",
                ),
                animation.Keyframe(
                    percentage=0.1,
                    transforms=[animation.Translate(0, 0)],
                ),
                animation.Keyframe(
                    percentage=0.9,
                    transforms=[animation.Translate(0, 0)],
                ),
                animation.Keyframe(
                    percentage=1.0,
                    transforms=[animation.Translate(-64, 0)],
                ),
            ],
        ),

        # 2 Current and Last Yearly Power Draw and Total Cost slide
        animation.Transformation(
            duration=175,
            delay=175,
            direction="normal",
            fill_mode="forwards",
            child=render_power_info(
                server_address, token, entity_total_energy, entity_total_cost),
            keyframes=[
                animation.Keyframe(
                    percentage=0.0,
                    transforms=[animation.Translate(64, 0)],
                    curve="linear",
                ),
                animation.Keyframe(
                    percentage=0.1,
                    transforms=[animation.Translate(0, 0)],
                ),
                animation.Keyframe(
                    percentage=0.9,
                    transforms=[animation.Translate(0, 0)],
                ),
                animation.Keyframe(
                    percentage=1.0,
                    transforms=[animation.Translate(-64, 0)],
                ),
            ],
        ),

    ])

    # Combine and render all elements
    return render.Root(
        render.Stack(
            children=[
                # Background
                render.Box(
                    width=64,
                    height=32,
                    color="#000"),
                # Foreground
                render.Stack(
                    children=slides,
                ),
            ]
        ),

    )

# ======================================
# Render Intro Logo slide
# ======================================
def render_intro_logo(brand_id):

    if brand_id == "unu":
        return render.Image(src=ICON_UNU)
    if brand_id == "niu":
        return render.Image(src=ICON_NIU)
    else:
        return render.Image(src=ICON_GENERIC)


# ======================================
# Render Yearly Power Info
# ======================================
def render_power_info(server_address, token, entity_total_energy, entity_total_cost):
    vals = yearly_three_from_ha(
        server_address, token, entity_total_energy, entity_total_cost)

    current = vals[0]
    last = vals[1]
    last_cost = vals[2]

    return render.Stack(
        children=[
            render.Column(
                main_align="start",
                children=[
                    render.Padding(
                        pad=(1, 1, 0, 0),
                        child=render.Row(
                            main_align="start",
                            children=[
                                render.Text("Yearly Power'"+str(current_year_short()),
                                            font="CG-pixel-3x5-mono", color=COLORS["unu_red"]),
                            ],
                        ),
                    ),
                    render.Padding(
                        pad=(1, 1, 0, 0),
                        child=render.Row(
                            main_align="start",
                            children=[
                                render.Text("" + str(current),
                                            font="Dina_r400-6", color=COLORS["text_primary"]),
                                render.Text(" KWh", font="Dina_r400-6",
                                            color=COLORS["text_secondary"]),
                            ],
                        ),
                    ),
                    render.Padding(
                        pad=(0, 1, 0, 1),
                        child=render.Box(
                            width=64,
                            height=1,
                            color=COLORS["unu_red"],),
                    ),
                    render.Column(
                        children=power_last_year_list(current_year(),
                                                      last, last_cost)
                    ),
                ],
            ),
        ]
    )


def power_last_year_list(current_year, powerYearlyLast, powerYearlyLastCost):
    powerYearlyLastList = []
    powerYearlyLastList.append(
        render.Padding(
            pad=(1, 0, 0, 0),
            child=render.Row(
                main_align="start",
                children=[
                    render.Text(str(powerYearlyLast),
                                font="CG-pixel-3x5-mono", color=COLORS["text_primary"]),
                    render.Text(
                        " KWh", font="CG-pixel-3x5-mono", color=COLORS["text_secondary"]),
                    render.Text(" " + str(current_year-1),
                                font="CG-pixel-3x5-mono", color=COLORS["text_primary"]),
                ],
            ),
        ),
    )
    powerYearlyLastList.append(
        render.Padding(
            pad=(1, 1, 0, 0),
            child=render.Row(
                main_align="start",
                children=[
                    render.Text(str(powerYearlyLastCost),
                                font="CG-pixel-3x5-mono", color=COLORS["unu_green"]),
                    render.Text(
                        " EUR", font="CG-pixel-3x5-mono", color=COLORS["text_secondary"]),
                    render.Text(" TOTAL",
                                font="CG-pixel-3x5-mono", color=COLORS["text_primary"]),
                ],
            ),
        ),
    )
    return powerYearlyLastList

# ======================================
# Helper: Render Yearly Power Info
# ======================================
def current_year():
    return int(time.now().format("2006"))

def current_year_short():
    return int(time.now().format("06"))

def yearly_three_from_ha(server_address, token, entity_yearly, entity_total_cost):
    cur = ha_state_float(server_address, token, entity_yearly, 0.0)
    last = ha_attr_float(server_address, token,
                         entity_yearly, "last_period", 0.0)

    total_cost = ha_state_float(server_address, token, entity_total_cost, 0.0)

    return [
        fmt_dec_comma_dynamic(cur),
        fmt_dec_comma_dynamic(last),
        fmt_dec_comma_dynamic(total_cost),
    ]

# ======================================
# Render Current / Weekly Power Graph
# ======================================
def render_currtent_charging_info(server_address, token, hours,
                                  entity_power_outlet,
                                  entity_charging_boolean, entity_total_charges_count):
    return render.Stack(
        children=[

            # Weekly Power Graph
            render.Column(
                main_align="start",
                children=[
                    plot_power_64px(server_address, token,
                                    hours, entity_power_outlet),
                ],
            ),

            # Total Charges Counter
            render.Column(
                main_align="start",
                children=[
                    render.Padding(
                        pad=(10, 16, 0, 0),
                        child=render.Row(
                            main_align="space_around",
                            cross_align="center",
                            children=[
                                render.Text(str(value_counter_string(server_address, token, entity_total_charges_count)),
                                            font="6x13", color="#ffffff"),
                                render.Text(" CHARGES", font="CG-pixel-3x5-mono",
                                            color=COLORS["text_secondary"]),
                            ],
                        ),
                    ),

                ],
            ),

            # Current Charging Power
            render.Column(
                main_align="start",
                children=[
                    render.Padding(
                        pad=(8, 1, 0, 0),
                        child=render.Row(
                            main_align="space_between",
                            cross_align="center",
                            children=[
                                # not used anymore, since we use power value to determine charging state
                                # render.Image(src=ICON_CHARGER_ON if entity_charging_boolean == "on" else ICON_CHARGER_OFF,
                                #              width=12, height=12),
                                render.Image(src=ICON_CHARGER_ON if is_charging(server_address, token, entity_power_outlet) == "on" else ICON_CHARGER_OFF,
                                             width=12, height=12),
                                render.Text("" + str(value_current_string(server_address, token, entity_power_outlet)),
                                            font="6x13", color=COLORS["text_primary"]),
                                render.Text(" W", font="6x13",
                                            color=COLORS["text_secondary"]),
                            ],
                        ),
                    ),

                ],
            ),
        ])


def plot_power_64px(server_address, token, hours, entity_power_outlet):
    vals = fetch_power_values_end(
        server_address, token, hours, entity_power_outlet)
    pts = to_xy_stretched(vals, 64)

    return render.Padding(
        pad=(0, 12, 0, 0),
        child=render.Plot(
            pts,
            chart_type="line",
            width=64,
            height=20,
            fill=True,
            x_lim=(0, 63),
            y_lim=(-5, 350),
            color=COLORS["unu_red"],
            color_inverted=COLORS["text_secondary"],
        ),
    )


# ======================================
# Helper: Render Current + Weekly Power Graph
# ======================================
def value_current_string(server_address, token, entity_id):
    v = ha_state_float(server_address, token, entity_id, 0.0)
    i = int(v)

    if i < 100:
        # floor auf 1 Nachkommastelle:
        vv = int(v * 10)          # z.B. 12.34 -> 123
        whole = vv // 10          # 12
        frac = vv - whole * 10    # 3
        out = str(whole) + "." + str(frac)
    else:
        out = str(i)

    return out.replace(".", ",")


def value_counter_string(server_address, token, entity_id):
    v = ha_state_float(server_address, token, entity_id, 0.0)

    # floor → int → string
    return str(int(v))

def is_charging(server_address, token, entity_id):
    v = ha_state_float(server_address, token, entity_id, 0.0)

    if v > 10:
        boolean_str = "on"
    else:
        boolean_str = "off"
    return boolean_str


def parse_ha_ts(ts):
    # Examples:
    # 2026-01-12T10:15:00.123456+00:00
    # 2026-01-12T10:15:00Z
    dot = ts.find(".")
    if dot != -1:
        plus = ts.rfind("+")
        minus = ts.rfind("-")
        tz = plus if plus > minus else minus
        if tz != -1:
            ts = ts[:dot] + ts[tz:]
        else:
            ts = ts[:dot] + "Z"

    return time.parse_time(ts, "2006-01-02T15:04:05Z07:00")


def fetch_power_values_end(server_address, token, hours, entity_power):
    base = normalize_server(server_address)

    end_sec = time.now().unix
    start_sec = end_sec - hours * 3600
    start_iso = time.from_timestamp(
        start_sec, 0).format("2006-01-02T15:04:05Z")

    # Fallback
    last = ha_state_float(base, token, entity_power, 0.0)

    url = "%s/api/history/period/%s?filter_entity_id=%s&minimal_response=1&significant_changes_only=0" % (
        base, start_iso, entity_power
    )
    resp = http.get(url, headers={"Authorization": "Bearer %s" % token})
    data = json.decode(http_body(resp))

    if len(data) == 0:
        out = []
        for _ in range(hours):
            out.append(last)
        return out

    series = data[0] or []

    points = []
    for it in series:
        s = it.get("s", it.get("state", None))
        ts = it.get("lu", it.get("last_updated", it.get("last_changed", None)))
        if s == None or ts == None or s in ["unknown", "unavailable", ""]:
            continue
        t = parse_ha_ts(ts)
        points.append((t.unix, float(s)))

    points = sorted(points, key=lambda p: p[0])

    values = []
    idx = 0
    plen = len(points)

    for h in range(hours):
        bucket_start = start_sec + h * 3600
        bucket_end = bucket_start + 3600

        end_val = last
        found = False

        for j in range(idx, plen):
            tsec = points[j][0]
            if tsec >= bucket_end:
                break
            if tsec >= bucket_start:
                end_val = points[j][1]
                found = True
            idx = j + 1

        last = end_val
        values.append(end_val if found else last)

    return values


def to_xy_stretched(vals, width):
    pts = []
    n = len(vals)
    if n <= 1:
        return pts

    for i in range(n):
        x = (i * (width - 1)) / (n - 1)
        pts.append((x, vals[i]))

    return pts


# ======================================
# Global Helper
# ======================================
def normalize_server(server_address):
    s = "%s" % server_address
    if not (s.startswith("http://") or s.startswith("https://")):
        s = "http://" + s
    if s.endswith("/"):
        s = s[:-1]
    return s


def http_body(resp):
    b = resp.body
    if type(b) != "string":
        b = b()
    return b


def ha_auth_ok(server_address, token):
    base = normalize_server(server_address)
    r = http.get("%s/api/" %
                 base, headers={"Authorization": "Bearer %s" % token})
    raw = http_body(r)
    # For correct tokens comes JSON with "message": "API running."
    return raw != "" and raw[0] == "{"


def ha_get_state_json(server_address, token, entity_id):
    base = normalize_server(server_address)
    url = "%s/api/states/%s" % (base, entity_id)

    r = http.get(
        url,
        headers={"Authorization": "Bearer %s" % token},
    )

    raw = http_body(r)

    # Check: must be JSON
    if raw == "" or raw[0] != "{":
        # optional Debug:
        print("HA response not JSON:", raw)
        return {}

    return json.decode(raw)


def ha_state_float(server_address, token, entity_id, default):
    j = ha_get_state_json(server_address, token, entity_id)
    s = j.get("state", None)
    if s in [None, "unknown", "unavailable", ""]:
        return default
    return float(s)


def ha_attr_float(server_address, token, entity_id, attr, default):
    j = ha_get_state_json(server_address, token, entity_id)
    attrs = j.get("attributes", {})
    v = attrs.get(attr, None)
    if v in [None, "unknown", "unavailable", ""]:
        return default
    return float(v)


def to_int_or_default(x, d):
    if x == None:
        return d

    # if tpye int already
    if type(x) == "int":
        return x

    # everything else to string
    s = "%s" % x

    if s == "":
        return d

    # Starlark-safe: int() direct
    v = int(s) if s.isdigit() else d
    return v


def fmt_3_dec_comma(v):
    # None / invalid safety
    if v == None:
        return "0,000"

    # floor to 3 decimal places
    vv = int(v * 1000)

    whole = vv // 1000
    frac = vv - whole * 1000

    # leading zeros for decimal part
    if frac < 10:
        frac_str = "00" + str(frac)
    elif frac < 100:
        frac_str = "0" + str(frac)
    else:
        frac_str = str(frac)

    return str(whole) + "," + frac_str


def fmt_dec_comma_dynamic(v):
    if v == None:
        return "0"

    if v < 10:
        mul = 1000
        dec = 3
    elif v < 100:
        mul = 100
        dec = 2
    elif v < 1000:
        mul = 10
        dec = 1
    else:
        mul = 1
        dec = 0

    vv = int(v * mul)
    whole = vv // mul
    frac = vv - whole * mul

    if dec == 0:
        return str(whole)

    # leading zeros for decimal part
    if dec == 1:
        frac_str = str(frac)
    elif dec == 2:
        frac_str = ("0" if frac < 10 else "") + str(frac)
    else:  # dec == 3
        frac_str = (
            "00" + str(frac) if frac < 10 else
            "0" + str(frac) if frac < 100 else
            str(frac)
        )

    return str(whole) + "," + frac_str
