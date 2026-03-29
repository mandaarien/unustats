# 🐈 PETKIT Cat Food Stats for Tidbyt / [Tronbyt Server](https://github.com/tronbyt/)
⚠️ Recommended to use the script/automation via HomeAssistant with [TidbytAssistant](https://github.com/savdagod/TidbytAssistant) for automations and display notifications.

This Pixlet applet shows (UNU/NIU/Other) Electric Scooter Charger Stats from Home Assistant on your Tidbyt. Needs Home Assistant with a Power Outlet Sensor and some Helper Entities to track Yearly Energy, Total Charges and Cost. 

- ℹ️ Choose Scooter Brand / (UNU/NNIU/Generic)
- ⏲️ Choose Informations to Show

## Preview

![Pixlet Preview](preview.gif) ![Pixlet Preview](output.gif)

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

## Tronbyt as Host
In Tronbyt you should be able to use the Configuration Scheme given in the app for setup of all arguments!
