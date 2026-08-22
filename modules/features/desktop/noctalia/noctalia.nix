{
  inputs,
  self,
  ...
}: {
  # noctalia rides along with the niri feature (niri spawns it at startup and
  # binds its IPC). These packages go into the niri module so `noctalia-shell`
  # and `noctalia-ipc` resolve via PATH (/run/current-system/sw/bin) — a stable
  # name instead of a per-generation store path.
  flake.modules.nixos.niri = {pkgs, ...}: {
    environment.systemPackages = [
      self.packages.${pkgs.stdenv.hostPlatform.system}.myNoctalia
      self.packages.${pkgs.stdenv.hostPlatform.system}.noctalia-ipc
    ];
  };

  perSystem = {
    pkgs,
    lib,
    self',
    ...
  }: let
    # The wallpaper installed by wallpapers/wallpaper.nix into ~/Pictures/Wallpapers.
    wallpaper = "/home/wiktor/Pictures/Wallpapers/wallhaven_p92g1m.jpg";
  in {
    # noctalia's IPC interface for niri binds and hooks. quickshell matches the
    # running instance by its `-p <pkg>/share/noctalia-shell` config path, so an
    # IPC client from a different generation than the running instance prints
    # "No running instances" (exit 255) and niri silently drops the bind — the
    # Mod+Space/Mod+P drift after rebuilds. This wrapper reads the -p path off
    # the running quickshell process and calls THAT build's client, so the pair
    # can never diverge; a baked store path to this script stays correct even
    # when stale, because the resolution happens at invocation time.
    packages.noctalia-ipc = pkgs.writeShellApplication {
      name = "noctalia-ipc";
      runtimeInputs = [pkgs.procps pkgs.gnugrep];
      text = ''
        share=$(pgrep -af 'quickshell -p .*/share/noctalia-shell' \
          | grep -oE '/nix/store/[^ ]+/share/noctalia-shell' | head -n1) || true
        client="''${share%/share/noctalia-shell}/bin/noctalia-shell"
        if [ -n "$share" ] && [ -x "$client" ]; then
          exec "$client" ipc "$@"
        fi
        # No running instance found: fall back to the current generation's
        # client on PATH (best effort, e.g. right after login).
        exec noctalia-shell ipc "$@"
      '';
    };

    packages.myNoctalia = inputs.wrapper-modules.wrappers.noctalia-shell.wrap {
      inherit pkgs;
      settings = {
        settingsVersion = 59;

        bar = {
          barType = "simple";
          position = "top";
          monitors = [];
          density = "default";
          showOutline = false;
          showCapsule = true;
          capsuleOpacity = 1;
          capsuleColorKey = "none";
          widgetSpacing = 6;
          contentPadding = 2;
          fontScale = 1;
          enableExclusionZoneInset = true;
          backgroundOpacity = 0.93;
          useSeparateOpacity = false;
          marginVertical = 4;
          marginHorizontal = 4;
          frameThickness = 8;
          frameRadius = 12;
          outerCorners = true;
          hideOnOverview = false;
          displayMode = "always_visible";
          autoHideDelay = 500;
          autoShowDelay = 150;
          showOnWorkspaceSwitch = true;
          mouseWheelAction = "none";
          reverseScroll = false;
          mouseWheelWrap = true;
          middleClickAction = "none";
          middleClickFollowMouse = false;
          middleClickCommand = "";
          rightClickAction = "controlCenter";
          rightClickFollowMouse = true;
          rightClickCommand = "";
          screenOverrides = [];

          widgets = {
            left = [
              {
                id = "Launcher";
                icon = "rocket";
                iconColor = "none";
                colorizeSystemIcon = "none";
                customIconPath = "";
                enableColorization = false;
                useDistroLogo = false;
              }
              {
                id = "Clock";
                clockColor = "none";
                customFont = "";
                formatHorizontal = "HH:mm ddd, MMM dd";
                formatVertical = "HH mm - dd MM";
                tooltipFormat = "HH:mm ddd, MMM dd";
                useCustomFont = false;
              }
              {
                id = "SystemMonitor";
                diskPath = "/";
                iconColor = "none";
                textColor = "none";
                compactMode = true;
                showCpuCores = false;
                showCpuFreq = false;
                showCpuTemp = true;
                showCpuUsage = true;
                showDiskAvailable = false;
                showDiskUsage = false;
                showDiskUsageAsPercent = false;
                showGpuTemp = false;
                showLoadAverage = false;
                showMemoryAsPercent = false;
                showMemoryUsage = true;
                showNetworkStats = false;
                showSwapUsage = false;
                useMonospaceFont = true;
                usePadding = false;
              }
              {
                id = "ActiveWindow";
                hideMode = "hidden";
                maxWidth = 145;
                scrollingMode = "hover";
                textColor = "none";
                colorizeIcons = false;
                showIcon = true;
                showText = true;
                useFixedWidth = false;
              }
              {
                id = "MediaMini";
                hideMode = "hidden";
                maxWidth = 145;
                scrollingMode = "hover";
                textColor = "none";
                visualizerType = "linear";
                compactMode = false;
                hideWhenIdle = false;
                panelShowAlbumArt = true;
                showAlbumArt = true;
                showArtistFirst = true;
                showProgressRing = true;
                showVisualizer = false;
                useFixedWidth = false;
              }
            ];

            center = [
              {
                id = "Workspace";
                emptyColor = "secondary";
                focusedColor = "primary";
                fontWeight = "bold";
                iconScale = 0.8;
                labelMode = "index";
                occupiedColor = "secondary";
                pillSize = 0.6;
                characterCount = 2;
                groupedBorderOpacity = 1;
                unfocusedIconsOpacity = 1;
                colorizeIcons = false;
                enableScrollWheel = true;
                followFocusedScreen = false;
                hideUnoccupied = false;
                showApplications = false;
                showApplicationsHover = false;
                showBadge = true;
                showLabelsOnlyWhenOccupied = true;
              }
              {
                id = "plugin:mini-docker";
                defaultSettings = {
                  refreshInterval = 5000;
                };
              }
              {
                id = "plugin:todo";
                defaultSettings = {
                  completedCount = 0;
                  count = 0;
                  current_page_id = 0;
                  exportEmptySections = false;
                  exportFormat = "markdown";
                  exportPath = "~/Documents";
                  isExpanded = false;
                  pages = [
                    {
                      id = 0;
                      name = "General";
                    }
                  ];
                  priorityColors = {
                    high = "#f44336";
                    medium = "#2196f3";
                    low = "#9e9e9e";
                  };
                  todos = [];
                  showBackground = true;
                  showCompleted = true;
                  useCustomColors = false;
                };
              }
            ];

            right = [
              {
                id = "plugin:tailscale";
                defaultSettings = {
                  refreshInterval = 5000;
                  pingCount = 5;
                  sshUsername = "";
                  taildropDownloadDir = "~/Downloads";
                  taildropReceiveMode = "operator";
                  terminalCommand = "";
                  defaultPeerAction = "copy-ip";
                  compactMode = false;
                  hideDisconnected = false;
                  hideMullvadExitNodes = true;
                  showIpAddress = true;
                  showPeerCount = true;
                  taildropEnabled = true;
                };
              }
              {
                id = "Tray";
                chevronColor = "none";
                blacklist = [];
                pinned = ["tray-icon tray app"];
                colorizeIcons = false;
                drawerEnabled = true;
                hidePassive = false;
              }
              {
                id = "NotificationHistory";
                iconColor = "none";
                unreadBadgeColor = "primary";
                hideWhenZero = false;
                hideWhenZeroUnread = false;
                showUnreadBadge = true;
              }
              {
                id = "Battery";
                deviceNativePath = "__default__";
                displayMode = "graphic-clean";
                hideIfIdle = false;
                hideIfNotDetected = true;
                showNoctaliaPerformance = false;
                showPowerProfiles = false;
              }
              {
                id = "Volume";
                displayMode = "onhover";
                iconColor = "none";
                textColor = "none";
                middleClickCommand = "pwvucontrol || pavucontrol";
              }
              {
                id = "Brightness";
                displayMode = "onhover";
                iconColor = "none";
                textColor = "none";
                applyToAllMonitors = false;
              }
              {
                id = "ControlCenter";
                icon = "noctalia";
                colorizeSystemIcon = "none";
                customIconPath = "";
                colorizeDistroLogo = false;
                enableColorization = false;
                useDistroLogo = false;
              }
            ];
          };
        };

        general = {
          avatarImage = "/home/wiktor/.face";
          dimmerOpacity = 0.2;
          scaleRatio = 1;
          radiusRatio = 1;
          iRadiusRatio = 1;
          boxRadiusRatio = 1;
          screenRadiusRatio = 1;
          animationSpeed = 1;
          shadowDirection = "bottom_right";
          shadowOffsetX = 2;
          shadowOffsetY = 3;
          language = "";
          clockStyle = "custom";
          clockFormat = "hh\\nmm";
          lockScreenMonitors = [];
          lockScreenBlur = 0;
          lockScreenTint = 0;
          lockScreenCountdownDuration = 10000;
          animationDisabled = false;
          autoStartAuth = false;
          allowPasswordWithFprintd = false;
          allowPanelsOnScreenWithoutBar = true;
          compactLockScreen = false;
          enableBlurBehind = true;
          enableLockScreenCountdown = true;
          enableLockScreenMediaControls = false;
          enableShadows = true;
          forceBlackScreenCorners = false;
          lockOnSuspend = true;
          lockScreenAnimations = false;
          passwordChars = false;
          reverseScroll = false;
          showChangelogOnStartup = true;
          showHibernateOnLockScreen = false;
          showScreenCorners = false;
          showSessionButtonsOnLockScreen = true;
          smoothScrollEnabled = true;
          telemetryEnabled = false;
          keybinds = {
            keyUp = ["Up"];
            keyDown = ["Down"];
            keyLeft = ["Left"];
            keyRight = ["Right"];
            keyEnter = ["Return" "Enter"];
            keyEscape = ["Esc"];
            keyRemove = ["Del"];
          };
        };

        ui = {
          fontDefault = "Sans";
          fontFixed = "monospace";
          fontDefaultScale = 0.9;
          fontFixedScale = 1;
          panelBackgroundOpacity = 0.93;
          settingsPanelMode = "attached";
          boxBorderEnabled = false;
          panelsAttachedToBar = true;
          scrollbarAlwaysVisible = true;
          settingsPanelSideBarCardStyle = false;
          tooltipsEnabled = true;
          translucentWidgets = false;
        };

        location = {
          name = "Gdansk";
          firstDayOfWeek = -1;
          analogClockInCalendar = false;
          autoLocate = false;
          hideWeatherCityName = false;
          hideWeatherTimezone = false;
          showCalendarEvents = true;
          showCalendarWeather = true;
          showWeekNumberInCalendar = false;
          use12hourFormat = false;
          useFahrenheit = false;
          weatherEnabled = true;
          weatherShowEffects = true;
          weatherTaliaMascotAlways = false;
        };

        calendar.cards = [
          {
            id = "calendar-header-card";
            enabled = true;
          }
          {
            id = "calendar-month-card";
            enabled = true;
          }
          {
            id = "weather-card";
            enabled = true;
          }
        ];

        wallpaper = {
          directory = "/home/wiktor/Pictures/Wallpapers";
          fillColor = "#000000";
          solidColor = "#1a1a2e";
          fillMode = "crop";
          viewMode = "single";
          wallpaperChangeMode = "random";
          panelPosition = "follow_bar";
          sortOrder = "name";
          transitionType = ["fade" "disc" "stripes" "wipe" "pixelate" "honeycomb"];
          monitorDirectories = [];
          favorites = [];
          randomIntervalSec = 300;
          transitionDuration = 1500;
          overviewBlur = 0.4;
          overviewTint = 0.6;
          transitionEdgeSmoothness = 0.05;
          automationEnabled = false;
          enabled = true;
          enableMultiMonitorDirectories = false;
          hideWallpaperFilenames = false;
          linkLightAndDarkWallpapers = true;
          overviewEnabled = false;
          setWallpaperOnAllMonitors = true;
          showHiddenFiles = false;
          skipStartupTransition = false;
          useOriginalImages = false;
          useSolidColor = false;
          useWallhaven = false;
          wallhavenApiKey = "";
          wallhavenCategories = "111";
          wallhavenOrder = "desc";
          wallhavenPurity = "100";
          wallhavenQuery = "";
          wallhavenRatios = "";
          wallhavenResolutionHeight = "";
          wallhavenResolutionMode = "atleast";
          wallhavenResolutionWidth = "";
          wallhavenSorting = "relevance";
        };

        appLauncher = {
          position = "center";
          viewMode = "list";
          iconMode = "tabler";
          density = "default";
          terminalCommand = "alacritty -e";
          clipboardWatchTextCommand = "wl-paste --type text --watch cliphist store";
          clipboardWatchImageCommand = "wl-paste --type image --watch cliphist store";
          customLaunchPrefix = "";
          screenshotAnnotationTool = "";
          pinnedApps = [];
          autoPasteClipboard = false;
          customLaunchPrefixEnabled = false;
          enableClipPreview = true;
          enableClipboardChips = true;
          enableClipboardHistory = false;
          enableClipboardSmartIcons = true;
          enableSessionSearch = true;
          enableSettingsSearch = true;
          enableWindowsSearch = true;
          clipboardWrapText = true;
          ignoreMouseInput = false;
          overviewLayer = false;
          showCategories = true;
          showIconBackground = false;
          sortByMostUsed = true;
        };

        controlCenter = {
          position = "close_to_bar_button";
          diskPath = "/";
          shortcuts = {
            left = [
              {id = "Network";}
              {id = "WiFi";}
              {id = "Bluetooth";}
              {id = "WallpaperSelector";}
              {id = "NoctaliaPerformance";}
            ];
            right = [
              {id = "Notifications";}
              {id = "PowerProfile";}
              {id = "KeepAwake";}
              {id = "NightLight";}
            ];
          };
          cards = [
            {
              id = "profile-card";
              enabled = true;
            }
            {
              id = "shortcuts-card";
              enabled = true;
            }
            {
              id = "audio-card";
              enabled = true;
            }
            {
              id = "brightness-card";
              enabled = false;
            }
            {
              id = "weather-card";
              enabled = true;
            }
            {
              id = "media-sysmon-card";
              enabled = true;
            }
          ];
        };

        systemMonitor = {
          externalMonitor = "resources || missioncenter || jdsystemmonitor || corestats || system-monitoring-center || gnome-system-monitor || plasma-systemmonitor || mate-system-monitor || ukui-system-monitor || deepin-system-monitor || pantheon-system-monitor";
          warningColor = "#83a598";
          criticalColor = "#fb4934";
          cpuWarningThreshold = 80;
          cpuCriticalThreshold = 90;
          tempWarningThreshold = 80;
          tempCriticalThreshold = 90;
          gpuWarningThreshold = 80;
          gpuCriticalThreshold = 90;
          memWarningThreshold = 80;
          memCriticalThreshold = 90;
          swapWarningThreshold = 80;
          swapCriticalThreshold = 90;
          diskWarningThreshold = 80;
          diskCriticalThreshold = 90;
          diskAvailWarningThreshold = 20;
          diskAvailCriticalThreshold = 10;
          batteryWarningThreshold = 20;
          batteryCriticalThreshold = 5;
          enableDgpuMonitoring = false;
          useCustomColors = false;
        };

        noctaliaPerformance = {
          disableWallpaper = true;
          disableDesktopWidgets = true;
        };

        dock = {
          position = "bottom";
          displayMode = "auto_hide";
          dockType = "floating";
          groupClickAction = "cycle";
          groupContextMenuMode = "extended";
          groupIndicatorStyle = "dots";
          indicatorColor = "primary";
          launcherIcon = "";
          launcherIconColor = "none";
          launcherPosition = "end";
          monitors = [];
          pinnedApps = [];
          backgroundOpacity = 1;
          floatingRatio = 1;
          size = 1;
          deadOpacity = 0.6;
          animationSpeed = 1;
          indicatorThickness = 3;
          indicatorOpacity = 0.6;
          colorizeIcons = true;
          enabled = true;
          groupApps = false;
          inactiveIndicators = false;
          launcherUseDistroLogo = false;
          onlySameOutput = true;
          pinnedStatic = false;
          showDockIndicator = false;
          showLauncherIcon = false;
          sitOnFrame = false;
        };

        network = {
          networkPanelView = "wifi";
          wifiDetailsViewMode = "grid";
          bluetoothDetailsViewMode = "grid";
          bluetoothRssiPollIntervalMs = 60000;
          bluetoothAutoConnect = true;
          bluetoothHideUnnamedDevices = false;
          bluetoothRssiPollingEnabled = false;
          disableDiscoverability = false;
        };

        sessionMenu = {
          position = "center";
          largeButtonsLayout = "single-row";
          countdownDuration = 10000;
          enableCountdown = true;
          largeButtonsStyle = true;
          showHeader = true;
          showKeybinds = true;
          powerOptions = [
            {
              action = "lock";
              keybind = "1";
              command = "";
              enabled = true;
              countdownEnabled = true;
            }
            {
              action = "suspend";
              keybind = "2";
              command = "";
              enabled = true;
              countdownEnabled = true;
            }
            {
              action = "hibernate";
              keybind = "3";
              command = "";
              enabled = true;
              countdownEnabled = true;
            }
            {
              action = "reboot";
              keybind = "4";
              command = "";
              enabled = true;
              countdownEnabled = true;
            }
            {
              action = "logout";
              keybind = "5";
              command = "";
              enabled = true;
              countdownEnabled = true;
            }
            {
              action = "shutdown";
              keybind = "6";
              command = "";
              enabled = true;
              countdownEnabled = true;
            }
            {
              action = "rebootToUefi";
              keybind = "7";
              command = "";
              enabled = true;
              countdownEnabled = true;
            }
            {
              action = "userspaceReboot";
              keybind = "";
              command = "";
              enabled = false;
              countdownEnabled = true;
            }
          ];
        };

        notifications = {
          location = "top_right";
          density = "default";
          monitors = [];
          lowUrgencyDuration = 3;
          normalUrgencyDuration = 8;
          criticalUrgencyDuration = 15;
          backgroundOpacity = 1;
          clearDismissed = true;
          enableBatteryToast = true;
          enableKeyboardLayoutToast = true;
          enableMarkdown = false;
          enableMediaToast = false;
          enabled = true;
          overlayLayer = true;
          respectExpireTimeout = false;
          saveToHistory = {
            low = true;
            normal = true;
            critical = true;
          };
          sounds = {
            excludedApps = "discord,firefox,chrome,chromium,edge";
            criticalSoundFile = "";
            normalSoundFile = "";
            lowSoundFile = "";
            volume = 0.5;
            enabled = false;
            separateSounds = false;
          };
        };

        osd = {
          location = "top_right";
          monitors = [];
          enabledTypes = [0 1 2];
          autoHideMs = 2000;
          backgroundOpacity = 1;
          enabled = true;
          overlayLayer = true;
        };

        audio = {
          visualizerType = "linear";
          preferredPlayer = "";
          volumeFeedbackSoundFile = "";
          mprisBlacklist = [];
          spectrumFrameRate = 30;
          volumeStep = 5;
          spectrumMirrored = true;
          volumeFeedback = false;
          volumeOverdrive = false;
        };

        brightness = {
          backlightDeviceMappings = [];
          brightnessStep = 5;
          enableDdcSupport = false;
          enforceMinimum = true;
        };

        colorSchemes = {
          predefinedScheme = "Gruvbox";
          schedulingMode = "off";
          generationMethod = "content";
          monitorForColors = "";
          manualSunrise = "06:30";
          manualSunset = "18:30";
          darkMode = true;
          syncGsettings = true;
          useWallpaperColors = false;
        };

        templates = {
          activeTemplates = [
            {
              id = "pywalfox";
              enabled = true;
            }
            {
              id = "discord";
              enabled = true;
            }
            {
              # Our actual terminal. Noctalia renders the active color scheme into
              # ~/.config/ghostty/themes/noctalia and (via its post-hook) keeps the
              # ghostty config's `theme = noctalia` line in sync. The config file
              # that references this theme is shipped declaratively by ghostty.nix.
              id = "ghostty";
              enabled = true;
            }
            {
              id = "code";
              enabled = true;
            }
            {
              id = "spicetify";
              enabled = true;
            }
            {
              id = "niri";
              enabled = true;
            }
          ];
          enableUserTheming = false;
        };

        nightLight = {
          nightTemp = "4000";
          dayTemp = "6500";
          manualSunrise = "06:30";
          manualSunset = "18:30";
          autoSchedule = true;
          enabled = false;
          forced = false;
        };

        hooks = {
          wallpaperChange = "";
          darkModeChange = "";
          screenLock = "";
          screenUnlock = "";
          performanceModeEnabled = "";
          performanceModeDisabled = "";
          # Pin our wallpaper on every startup. Noctalia stores the active
          # wallpaper only in the writable cache (~/.cache/noctalia/wallpapers.json),
          # not in the read-only store settings.json, so without this a fresh
          # cache (new machine / VM / cleared cache) falls back to the bundled
          # default instead of ours. noctalia-ipc resolves the client from the
          # running instance, so the pair can't drift across generations.
          startup = "${lib.getExe self'.packages.noctalia-ipc} call wallpaper set ${wallpaper} all";
          session = "";
          colorGeneration = "";
          enabled = true;
        };

        plugins = {
          autoUpdate = false;
          notifyUpdates = true;
        };

        idle = {
          screenOffCommand = "";
          lockCommand = "";
          suspendCommand = "";
          resumeScreenOffCommand = "";
          resumeLockCommand = "";
          resumeSuspendCommand = "";
          customCommands = "[]";
          screenOffTimeout = 600;
          lockTimeout = 660;
          suspendTimeout = 0;
          fadeDuration = 5;
          enabled = true;
        };

        desktopWidgets = {
          monitorWidgets = [];
          enabled = false;
          gridSnap = false;
          gridSnapScale = false;
          overviewEnabled = true;
        };
      };
    };
  };
}
