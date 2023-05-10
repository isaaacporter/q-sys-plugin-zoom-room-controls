local CurrentPage = PageNames[props["page_index"].Value]
if CurrentPage == "Main" then
  table.insert(graphics,{
    Type = "Text",
    Text = "Status",
    FontSize = 11,
    HTextAlign = "Left",
    Position = {0, 0},
    Size = {60, 32}
  })
  layout["Status"] = {
    PrettyName = "Status",
    Style = "Text",
    Margin = 0,
    CornerRadius = 0,
    Color = {194, 194, 194},
    Position = {63, 0},
    Size = {159, 32}
  }
  table.insert(graphics,{
    Type = "Text",
    Text = "Port",
    FontSize = 11,
    HTextAlign = "Left",
    Position = {0, 35},
    Size = {60, 16}
  })
  layout["Port"] = {
    PrettyName = "Status",
    Style = "Text",
    Margin = 0,
    CornerRadius = 0,
    Color = {110, 198, 241},
    Position = {63, 35},
    Size = {120, 16}
  }
  for idx = 1, props["Command Count"].Value do
    layout["command."..idx..".trigger"] = {
      PrettyName = "Command "..idx.."~Trigger",
      Style = "Button",
      Margin = 0,
      Position = {186, 35 + (19 * idx)},
      Size = {36, 16}
    }
    layout["command."..idx..".string"] = {
      PrettyName = "Command "..idx.."~String",
      Style = "Text",
      Margin = 0,
      CornerRadius = 0,
      Color = {255, 255, 255},
      Position = {0, 35 + (19 * idx)},
      Size = {183, 16}
    }
  end
end