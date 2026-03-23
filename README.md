# ElvUI Castbar Anchors

**The smart addon that works BOTH ways!**

## 🎯 Dual Mode System

This addon automatically detects your setup and runs in the best mode:

### 🔌 With ElvUI Installed → **Plugin Mode**
- Settings appear in ElvUI config (`/ec` → Plugins → Castbar Anchors)
- Settings stored in ElvUI profiles (sync when you switch profiles!)
- Native ElvUI look and feel
- Minimap icon ✅
- Addon compartment ✅

### 🚀 Without ElvUI → **Standalone Mode**
- Custom dark-themed settings window (`/ca`)
- Separate saved variables
- Full-featured modern UI
- Minimap icon ✅
- Addon compartment ✅

**Same features, different interface!**

## ✨ Features

- **Pet Frame Override** - Player castbar auto-switches to pet frame when pet is active
- **Precision Control** - Fine-tune X/Y offsets with sliders or direct input
- **Real-time Updates** - Smooth position tracking (adjustable update rate)
- **Three Castbars** - Player, Target, and Focus
- **Profile Support** - Global or character-specific (Standalone) / ElvUI profiles (Plugin)

## 📦 Installation

1. Extract `ElvUI_Castbar_Anchors` to `World of Warcraft\_retail_\Interface\AddOns`
2. Restart WoW or `/reload`
3. The addon auto-detects ElvUI and chooses the best mode

## 🎮 Usage

### Opening Settings

**Plugin Mode (with ElvUI):**
- Type `/ec` → Plugins → Castbar Anchors
- Click minimap icon
- Click addon compartment button

**Standalone Mode (without ElvUI):**
- Type `/ca`
- Click minimap icon
- Click addon compartment button

### Basic Setup

1. Enable the castbar you want (Player/Target/Focus)
2. Enter frame name (use `/fstack` to find frames)
3. Choose anchor points
4. Adjust X/Y offsets
5. Set update rate (lower = smoother)

### Pet Frame Override (Player Only)

1. Enable "Use Pet Frame when Active"
2. Enter pet frame name (e.g., `ElvUF_Pet`)
3. Castbar follows pet when active, falls back to main frame when no pet

## 📋 Common Frame Names

- `ElvUF_Player` - Player frame
- `ElvUF_Target` - Target frame
- `ElvUF_Focus` - Focus frame
- `ElvUF_Pet` - Pet frame
- Use `/fstack` to find custom frames (WeakAuras, etc.)

## 🔧 Requirements

- **ElvUI** - Optional (enables Plugin Mode)
- WoW: The War Within (12.0.1+)

## 📊 How It Works

The addon loads different files based on ElvUI presence:

```
ElvUI Detected?
├── YES → Core_Plugin.lua loads (ElvUI plugin)
└── NO  → Core.lua + Settings.lua load (Standalone)
```

Both modes have:
- All features
- Minimap icon
- Addon compartment
- Pet frame override
- Real-time updates

## 🎨 UI Comparison

| Feature | Plugin Mode | Standalone Mode |
|---------|-------------|-----------------|
| Settings Location | ElvUI Config | Custom Window |
| Profile System | ElvUI Profiles | Global/Character |
| Style | ElvUI Native | Dark Modern UI |
| Features | ✅ All | ✅ All |

## 💡 Why Dual Mode?

- **Flexibility** - Works for everyone
- **ElvUI Users** - Get native integration
- **Non-ElvUI Users** - Still get full features
- **Best of Both** - Same addon, optimized experience

## 🆘 Support

If something doesn't work, check:
1. Did addon load? Type `/reload`
2. Using correct command? (`/ca` standalone, `/ec` plugin)
3. ElvUI castbars enabled? (Settings → UnitFrames → Player/Target/Focus → Castbar)

## 📝 Version

**v2.2.0** - Dual Mode Release

- ✅ Full ElvUI plugin integration
- ✅ Complete standalone mode
- ✅ Automatic mode detection
- ✅ All features in both modes

---

**One addon. Two modes. Zero compromise.** 🚀
