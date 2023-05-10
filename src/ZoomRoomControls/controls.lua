table.insert(ctrls, {
  Name = "Status",
  ControlType = "Indicator",
  IndicatorType = "Status",
  UserPin = true,
  PinStyle = "Output"
})
table.insert(ctrls, {
  Name = "Port",
  ControlType = "Knob",
  ControlUnit = "Integer",
  DefaultValue = 50000,
  Min = 1,
  Max = 65535,
  UserPin = true,
  PinStyle = "Both"
})
for idx = 1, props["Command Count"].Value do
  table.insert(ctrls, {
    Name = "command."..idx..".trigger",
    ControlType = "Button",
    ButtonType = "Trigger",
    Count = 1,
    UserPin = true,
    PinStyle = "Output",
  })
  table.insert(ctrls, {
    Name = "command."..idx..".string",
    ControlType = "Text",
    IndicatorType = "Text",
    Count = 1,
    UserPin = true,
    PinStyle = "Both",
  })
end