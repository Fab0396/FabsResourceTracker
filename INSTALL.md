# Quick Installation Guide

## ⚠️ REQUIREMENTS
**This addon requires ElvUI to be installed and enabled.**

The addon works with these ElvUI castbars:
- Player Castbar (`ElvUF_Player_CastBar`)
- Target Castbar (`ElvUF_Target_CastBar`)
- Focus Castbar (`ElvUF_Focus_CastBar`)

## Installation Steps

1. **Locate your WoW AddOns folder:**
   - Windows: `C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\`
   - Mac: `/Applications/World of Warcraft/_retail_/Interface/AddOns/`

2. **Copy the entire `CastbarAnchorer` folder** into the AddOns directory

3. **Restart World of Warcraft** or type `/reload` if you're already in game

4. **Verify installation:**
   - Type `/ca` in chat - you should see the settings window
   - Look for a minimap icon with a spell icon
   - Check the AddOns list at character select screen

## Quick Start

1. Type `/ca` to open settings
2. Select which castbar (Player/Target/Focus) from the dropdown
3. Use `/fstack` in-game and hover over a frame you want to anchor to
4. Note the frame name (e.g., "ElvUF_Player", "ElvUF_Target")
5. Enter the frame name in settings and click "Set Anchor"
6. Adjust position as needed!

## Example Usage

**Anchor player castbar below player frame:**
```
/ca player
/ca setanchor ElvUF_Player
(Then in UI: set Relative Point to "BOTTOM", Offset Y to -30)
```

**Anchor target castbar to target frame:**
```
/ca target
/ca setanchor ElvUF_Target
```

## Troubleshooting

**Addon not loading?**
- Make sure the folder is named exactly `CastbarAnchorer`
- Check that all files are present (see folder structure below)
- Verify ElvUI is installed and enabled
- Verify AddOns are enabled at character select

**Castbar not found error?**
- Make sure ElvUI is loaded and enabled
- Check that ElvUI castbars are enabled in ElvUI settings
- The exact frame names are: `ElvUF_Player_CastBar`, `ElvUF_Target_CastBar`, `ElvUF_Focus_CastBar`

**Can't find frame names?**
- Type `/fstack` then hover your mouse over UI elements
- Look at the top of the list for the frame name

## Folder Structure

```
CastbarAnchorer/
├── CastbarAnchorer.toc
├── Core.lua
├── Settings.lua
├── README.md
└── Libs/
    ├── LibStub.lua
    ├── CallbackHandler-1.0.lua
    └── LibDBIcon-1.0/
        ├── LibDataBroker-1.1.lua
        └── LibDBIcon-1.0.lua
```

## Need Help?

See the full README.md for detailed documentation and examples!
