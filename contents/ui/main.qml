import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import org.kde.plasma.components as PC
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: "NoBackground"
    
    width: 500
    height: 700
    
    // Background
    Rectangle {
        anchors.fill: parent
        color: root.effectiveBackgroundColor
        opacity: root.backgroundOpacity
        radius: 10
        visible: !root.isDesktopContainment && root.backgroundOpacity > 0
        
        // Add a subtle border only if visible
        border.color: Qt.rgba(1, 1, 1, 0.1)
        border.width: 1
    }

    // Initial Loading State
    BusyIndicator {
        anchors.centerIn: parent
        running: pinterestModel.count === 0 && root.lastError === ""
        visible: running
        z: 999
    }

    // Widget properties - REDUCED limits to prevent crashes
    property string pinterestUsername: "pinterest"
    // Dynamic path resolution function
    function getScriptPath(filename) {
        var path = Qt.resolvedUrl("../" + filename)
        // Strip file:// prefix and decode URI components (e.g. %20 -> space)
        var cleanPath = path.toString().replace(/^file:\/\//, "")
        return decodeURIComponent(cleanPath)
    }

    // Helper to get opaque version of a color
    function getOpaqueColor(color) {
        return Qt.rgba(color.r, color.g, color.b, 1.0)
    }

    property string scriptPath: getScriptPath("fetchpinterest.py")
    property string saveScriptPath: getScriptPath("save_pinterest_pin.py")
    property string feedType: "search" // Default to search so it works immediately without auth
    property string searchQuery: "nature" // Default query
    property int maxPins: 18
    property int refreshInterval: 300000 // 5 minutes
    
    // Opacity Settings
    property double backgroundOpacity: 0.0 // Default to fully transparent like original
    property double pinOpacity: 1.0 // Default to fully opaque pins
    
    // UI Customization
    property bool showSettingsButton: true
    property bool showRefreshButton: true
    property string customBackgroundColor: "" // Empty means use theme color, otherwise hex code
    
    // Resolve background color to a proper color object
    readonly property color effectiveBackgroundColor: customBackgroundColor !== "" ? customBackgroundColor : Kirigami.Theme.backgroundColor

    // STRICT image loading control to prevent crashes
    property int maxConcurrentImages: 3 // ONLY 1 image at a time
    property int imageLoadDelay: 300 // 1 second delay between images
    property var loadingQueue: []
    property int currentlyLoading: 0
    property var loadedImages: new Set() // Track successfully loaded images

    // Add fetch counter to force fresh data
    property int fetchCounter: 0

    // Track saved states
    property var savedPins: ({}) // Object to track which pins have been saved
    property string lastError: ""

    // Preferred sizes

    // Preferred sizes
    preferredRepresentation: fullRepresentation
    Layout.minimumWidth: 400
    Layout.minimumHeight: 600
    Layout.preferredWidth: 450
    Layout.preferredHeight: 700

    // Data source for saving pins
    P5Support.DataSource {
        id: saveDataSource
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            console.log("Save operation completed for:", sourceName)

            // Extract pin ID from the command
            var pinId = extractPinIdFromCommand(sourceName)

            if (data['exit code'] === 0) {
                console.log("Pin saved successfully:", pinId)
                // Mark as saved instead of removing from saving state
                if (pinId) {
                    root.savedPins[pinId] = true
                    root.savedPinsChanged() // Trigger property binding updates
                }
            } else {
                console.log("Error saving pin:", pinId, data.stderr)
                // Remove from saved state on error
                if (pinId && root.savedPins[pinId]) {
                    delete root.savedPins[pinId]
                    root.savedPinsChanged()
                }
            }
        }
    }

    // Helper function to extract pin ID from command
    function extractPinIdFromCommand(command) {
        var parts = command.split(' ')
        return parts[parts.length - 1] // Last part should be the pin ID
    }

    // Function to save a pin
    function savePinToProfile(pinId) {
        if (!pinId || root.savedPins[pinId]) {
            console.log("Pin already saved or invalid ID:", pinId)
            return
        }

        console.log("Saving pin to profile:", pinId)
        // Immediately mark as saved for instant UI feedback
        root.savedPins[pinId] = true
        root.savedPinsChanged() // Trigger property binding updates

        var command = "python3 '" + root.saveScriptPath + "' '" + pinId + "'"
        console.log("Executing save command:", command)
        saveDataSource.connectSource(command)
    }

    // Configuration Popup
    Popup {
        id: configPopup
        width: 425
        height: 375
        anchors.centerIn: parent
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        function open() {
            usernameField.text = root.pinterestUsername
            searchQueryField.text = root.searchQuery
            intervalSpinBox.value = root.refreshInterval / 60000
            bgOpacitySlider.value = root.backgroundOpacity
            pinOpacitySlider.value = root.pinOpacity
            showSettingsCheck.checked = root.showSettingsButton
            showRefreshCheck.checked = root.showRefreshButton
            bgColorField.text = root.customBackgroundColor

            // Set the correct radio button
            personalFeedRadio.checked = (root.feedType === "personal")
            userFeedRadio.checked = (root.feedType === "user")
            searchFeedRadio.checked = (root.feedType === "search")

            configPopup.visible = true
        }

        background: Rectangle {
            color: Kirigami.Theme.backgroundColor
            border.color: PlasmaCore.Theme.buttonFocusColor || "#3daee9"
            border.width: 1
            radius: 6

            ScrollView {
                anchors.fill: parent
                anchors.margins: 10
                clip: true
                contentWidth: availableWidth

                ColumnLayout {
                    width: parent.width
                    spacing: 15

                    PC.Label {
                        text: "Pinterest Widget Configuration"
                        font.bold: true
                        font.pixelSize: 16
                        color: PlasmaCore.Theme.textColor || "#eff0f1"
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                // Feed Type Selection
                GroupBox {
                    title: "Feed Source"
                    Layout.fillWidth: true
                    
                    ColumnLayout {
                        RadioButton {
                            id: personalFeedRadio
                            text: "Personal Home Feed (Auth Required)"
                            checked: true
                        }
                        RadioButton {
                            id: userFeedRadio
                            text: "Specific User"
                        }
                        RadioButton {
                            id: searchFeedRadio
                            text: "Search Query"
                        }
                    }
                }

                // Input Fields
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: userFeedRadio.checked
                    
                    PC.Label {
                        text: "Pinterest Username:"
                        color: PlasmaCore.Theme.textColor || "#eff0f1"
                    }
                    TextField {
                        id: usernameField
                        Layout.fillWidth: true
                        placeholderText: "e.g. pinterest"
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: searchFeedRadio.checked
                    
                    PC.Label {
                        text: "Search Query:"
                        color: PlasmaCore.Theme.textColor || "#eff0f1"
                    }
                    TextField {
                        id: searchQueryField
                        Layout.fillWidth: true
                        placeholderText: "e.g. nature, architecture"
                    }
                }

                // Advanced Settings
                PC.Label {
                    text: "Max Pins to Fetch:"
                    color: PlasmaCore.Theme.textColor || "#eff0f1"
                }
                SpinBox {
                    id: maxPinsSpinBox
                    Layout.fillWidth: true
                    from: 5
                    to: 50
                    value: root.maxPins
                }

                PC.Label {
                    text: "Refresh Interval (minutes):"
                    font.bold: true
                    color: PlasmaCore.Theme.textColor || "#eff0f1"
                }

                SpinBox {
                    id: intervalSpinBox
                    Layout.fillWidth: true
                    from: 5 // Minimum 5 minutes
                    to: 60
                    value: root.refreshInterval / 60000
                }

                // Opacity Settings
                PC.Label {
                    text: "Background Opacity (" + Math.round(bgOpacitySlider.value * 100) + "%):"
                    font.bold: true
                    color: PlasmaCore.Theme.textColor || "#eff0f1"
                }

                Slider {
                    id: bgOpacitySlider
                    Layout.fillWidth: true
                    from: 0.0
                    to: 1.0
                    value: root.backgroundOpacity
                }

                PC.Label {
                    text: "Pin Opacity (" + Math.round(pinOpacitySlider.value * 100) + "%):"
                    font.bold: true
                    color: PlasmaCore.Theme.textColor || "#eff0f1"
                }

                Slider {
                    id: pinOpacitySlider
                    Layout.fillWidth: true
                    from: 0.1
                    to: 1.0
                    value: root.pinOpacity
                }

                // UI Customization
                GroupBox {
                    title: "UI Settings"
                    Layout.fillWidth: true

                    ColumnLayout {
                        anchors.fill: parent
                        
                        CheckBox {
                            id: showSettingsCheck
                            text: "Show Settings Button"
                            checked: root.showSettingsButton
                        }

                        CheckBox {
                            id: showRefreshCheck
                            text: "Show Refresh Button"
                            checked: root.showRefreshButton
                        }

                        PC.Label {
                            text: "Custom Background Color (Hex):"
                            color: PlasmaCore.Theme.textColor || "#eff0f1"
                        }

                        TextField {
                            id: bgColorField
                            Layout.fillWidth: true
                            text: root.customBackgroundColor
                            placeholderText: "#RRGGBB or empty for theme"
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    
                    PC.Button {
                        text: "Setup Auth"
                        icon.name: "configure"
                        onClicked: {
                            // Use dynamic path to the setup script
                            var script = getScriptPath("pinterest_setup.py")
                            console.log("=== SETUP AUTH DEBUG ===")
                            console.log("Using script path:", script)
                            var cmd = "konsole --hold -e python3 '" + script + "'"
                            console.log("Launching setup script:", cmd)
                            console.log("========================")
                            // Use DataSource to execute command
                            saveDataSource.connectSource(cmd)
                        }
                    }
                    
                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Cancel"
                        onClicked: configPopup.close()
                    }

                    Button {
                        text: "Apply"
                        highlighted: true
                        enabled: {
                            // Validation: require username for user feed, search query for search feed
                            if (userFeedRadio.checked) {
                                return usernameField.text.trim() !== ""
                            } else if (searchFeedRadio.checked) {
                                return searchQueryField.text.trim() !== ""
                            }
                            return true // Personal feed doesn't require additional input
                        }
                        onClicked: {
                            // Determine feed type
                            if (personalFeedRadio.checked) {
                                root.feedType = "personal"
                            } else if (userFeedRadio.checked) {
                                root.feedType = "user"
                            } else if (searchFeedRadio.checked) {
                                root.feedType = "search"
                            }

                            root.pinterestUsername = usernameField.text.trim()
                            root.searchQuery = searchQueryField.text.trim()
                            root.maxPins = maxPinsSpinBox.value
                            root.refreshInterval = Math.max(300000, intervalSpinBox.value * 60000) // Min 5 minutes
                            root.backgroundOpacity = bgOpacitySlider.value
                            root.pinOpacity = pinOpacitySlider.value
                            root.showSettingsButton = showSettingsCheck.checked
                            root.showRefreshButton = showRefreshCheck.checked
                            root.customBackgroundColor = bgColorField.text.trim()
                            root.scriptPath = scriptPathField.text
                            root.saveScriptPath = saveScriptPathField.text
                            refreshTimer.interval = root.refreshInterval
                            configPopup.close()

                            // Clear everything before fetching new data
                            clearAllData()
                            fetchPinterestData()
                        }
                    }
                }
            }
        }
    }
    }

    // Hidden fields to store paths (for persistence if needed)
    TextField {
        id: scriptPathField
        visible: false
        text: root.scriptPath
    }
    TextField {
        id: saveScriptPathField
        visible: false
        text: root.saveScriptPath
    }



    // CRASH PREVENTION: Clear all image data and reset state
    function clearAllData() {
        console.log("Clearing all image data to prevent crashes...")

        // Stop all timers
        imageLoadTimer.stop()
        refreshTimer.stop()

        // Clear loading state
        loadingQueue = []
        currentlyLoading = 0
        loadedImages.clear()

        // Clear saving states
        savedPins = {}

        // Clear model
        pinterestModel.clear()

        // IMPORTANT: Disconnect all data sources to clear cache
        disconnectAllSources()

        // Force garbage collection
        gc()

        // Restart refresh timer
        refreshTimer.start()
    }

    // NEW: Function to properly disconnect all sources
    function disconnectAllSources() {
        console.log("Disconnecting all data sources...")
        var sources = pinterestDataSource.connectedSources
        for (var i = 0; i < sources.length; i++) {
            console.log("Disconnecting source:", sources[i])
            pinterestDataSource.disconnectSource(sources[i])
        }

        // Also disconnect save data source
        var saveSources = saveDataSource.connectedSources
        for (var j = 0; j < saveSources.length; j++) {
            console.log("Disconnecting save source:", saveSources[j])
            saveDataSource.disconnectSource(saveSources[j])
        }

        // Wait a moment before allowing new connections
        Qt.callLater(function() {
            console.log("All sources disconnected, ready for fresh fetch")
        })
    }

    // SAFE image loading timer with longer delays
    Timer {
        id: imageLoadTimer
        interval: imageLoadDelay
        repeat: false
        onTriggered: processImageQueue()
    }

    // CRASH-SAFE image loading queue management
    function addToImageQueue(imageComponent) {
        if (!imageComponent || !imageComponent.shouldLoad) {
            return
        }

        // Check if already in queue
        for (var i = 0; i < loadingQueue.length; i++) {
            if (loadingQueue[i] === imageComponent) {
                return // Already queued
            }
        }

        loadingQueue.push(imageComponent)
        processImageQueue()
    }

    function processImageQueue() {
        // STRICT: Only process if under limits
        if (currentlyLoading >= maxConcurrentImages || loadingQueue.length === 0) {
            return
        }

        var imageComponent = loadingQueue.shift()
        if (imageComponent && imageComponent.shouldLoad && !imageComponent.loadStarted) {
            currentlyLoading++
            console.log("Starting image load, currently loading:", currentlyLoading)
            imageComponent.startLoading()
        }

        // Continue processing queue with delay
        if (loadingQueue.length > 0 && currentlyLoading < maxConcurrentImages) {
            imageLoadTimer.start()
        }
    }

    function imageLoadComplete(success) {
        currentlyLoading = Math.max(0, currentlyLoading - 1)
        console.log("Image load complete, success:", success, "currently loading:", currentlyLoading)

        // Continue queue processing
        if (loadingQueue.length > 0) {
            imageLoadTimer.start()
        }
    }

    // CRASH-SAFE data source with timeout protection
    P5Support.DataSource {
        id: pinterestDataSource
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            console.log("DataSource received data for:", sourceName)

            if (data['exit code'] > 0) {
                console.log("Error fetching Pinterest data:", data.stderr)
                root.lastError = data.stderr
                return
            }
            root.lastError = ""

            try {
                var response = JSON.parse(data.stdout)
                console.log("Parsed response - found", response.data ? response.data.length : 0, "pins")

                // CRASH PREVENTION: Clear everything first
                clearAllData()

                if (response && response.data && response.data.length > 0) {
                    // STRICT LIMITS: Only process up to maxPins
                    var validPins = 0
                    for (var i = 0; i < response.data.length && validPins < root.maxPins; i++) {
                        var pin = response.data[i]
                        var imageUrl = pin.images?.orig?.url || pin.images?.['564x']?.url || ""

                        // STRICT validation: Only Pinterest URLs
                        if (imageUrl && imageUrl.includes("pinimg.com") && imageUrl.startsWith("https://")) {
                            pinterestModel.append({
                                id: pin.id || `pin_${i}`,
                                title: pin.title || "Pinterest Pin",
                                description: pin.description || "",
                                imageUrl: imageUrl,
                                link: pin.link || "",
                                boardName: pin.board?.name || "",
                                pinUrl: pin.link || `https://pinterest.com/pin/${pin.id || ""}`,
                                loadIndex: validPins // For sequential loading
                            })
                            validPins++
                        }
                    }
                } else {
                    console.log("No pins found")
                }

            } catch (e) {
                console.log("Error parsing Pinterest data:", e)
                clearAllData()
            }
        }
    }

    ListModel {
        id: pinterestModel
    }

    // Slower refresh timer to prevent overload
    Timer {
        id: refreshTimer
        interval: refreshInterval
        running: true
        repeat: true
        onTriggered: {
            // Only refresh if not currently loading images
            if (currentlyLoading === 0) {
                fetchPinterestData()
            } else {
                console.log("Skipping refresh - images still loading")
            }
        }
    }

    function fetchPinterestData() {
        // CRASH PREVENTION: Don't fetch if already loading
        if (currentlyLoading > 0) {
            console.log("Already loading images, skipping fetch")
            return
        }

        // Increment fetch counter to ensure fresh data
        fetchCounter++
        console.log("Fetching Pinterest data with maxPins:", root.maxPins, "fetch #", fetchCounter, "feed type:", feedType)

        // CRITICAL: Disconnect ALL sources first to clear any cache
        disconnectAllSources()

        // Wait a moment then connect with unique command
        Qt.callLater(function() {
            var command;
            var timestamp = Date.now(); // Add timestamp for uniqueness

            if (feedType === "personal") {
                command = "python3 '" + scriptPath + "' home_feed " + root.maxPins + " --refresh=" + timestamp
            } else if (feedType === "search") {
                // Validate search query
                if (!searchQuery || searchQuery.trim() === "") {
                    console.log("No search query provided, skipping fetch")
                    return
                }
                command = "python3 '" + scriptPath + "' 'search:" + searchQuery.trim() + "' " + root.maxPins + " --refresh=" + timestamp
            } else {
                // Default to user feed
                if (!pinterestUsername || pinterestUsername.trim() === "") {
                    console.log("No username provided, skipping fetch")
                    return
                }
                command = "python3 '" + scriptPath + "' '" + pinterestUsername.trim() + "' " + root.maxPins + " --refresh=" + timestamp
            }

            console.log("Executing fresh command:", command)
            pinterestDataSource.connectSource(command)
        })
    }

    // Function to get current feed display name for UI
    function getCurrentFeedDisplayName() {
        switch (feedType) {
            case "personal":
                return "Personal Feed"
            case "search":
                return "Search: " + (searchQuery || "No query")
            case "user":
                return "User: " + (pinterestUsername || "No user")
            default:
                return "Pinterest"
        }
    }

    // Main widget content

    fullRepresentation: Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        // Configuration access
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    configPopup.open()
                }
            }
            z: 0
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Header Bar
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                Layout.margins: 10
                z: 100

                // Spacer to push buttons to the right
                Item {
                    Layout.fillWidth: true
                }

                PC.ToolButton {
                    id: settingsButton
                    icon.name: "configure"
                    text: "Settings"
                    display: AbstractButton.IconOnly
                    visible: root.showSettingsButton
                    onClicked: configPopup.open()
                }

                PC.ToolButton {
                    id: refreshButton
                    icon.name: "view-refresh"
                    text: "Refresh"
                    display: AbstractButton.IconOnly
                    enabled: currentlyLoading === 0
                    visible: root.showRefreshButton
                    onClicked: {
                        console.log("Manual refresh triggered")
                        clearAllData()
                        fetchPinterestData()
                        refreshAnimation.start()
                    }

                    RotationAnimation {
                        id: refreshAnimation
                        target: refreshButton.contentItem
                        property: "rotation"
                        from: 0
                        to: 360
                        duration: 1000
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            // Main Grid View
            ScrollView {
                id: scrollView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                GridView {
                id: pinterestGridView
                model: pinterestModel
                cellWidth: width / Math.max(1, Math.floor(width / 200)) // Larger cells for fewer pins
                cellHeight: cellWidth * 1.4

                delegate: Item {
                    width: pinterestGridView.cellWidth
                    height: pinterestGridView.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 8
                        // Pin card background - use theme card color with pin opacity
                        color: Qt.rgba(
                            Kirigami.Theme.backgroundColor.r,
                            Kirigami.Theme.backgroundColor.g,
                            Kirigami.Theme.backgroundColor.b,
                            1.0  // Keep card fully opaque
                        )
                        radius: 12
                        // Apply pin opacity to the entire card
                        opacity: root.pinOpacity
                        
                        // Drop Shadow
                        layer.enabled: true
                        layer.effect: DropShadow {
                            transparentBorder: true
                            horizontalOffset: 0
                            verticalOffset: 2
                            radius: 8
                            samples: 16
                            color: Qt.rgba(0, 0, 0, 0.2)
                        }

                        // CRASH-SAFE image loading component
                        Item {
                            id: imageContainer
                            anchors.fill: parent

                            property bool shouldLoad: true
                            property bool isLoading: false
                            property bool loadStarted: false
                            property bool hasError: false
                            property string imageId: model.id || ""

                            function startLoading() {
                                if (loadStarted || hasError || !model.imageUrl) {
                                    imageLoadComplete(false)
                                    return
                                }

                                loadStarted = true
                                isLoading = true
                                console.log(`=== LOADING IMAGE ===`)
                                console.log(`Pin ID: ${model.id}`)
                                console.log(`Order: ${model.loadIndex}`)
                                console.log(`Image URL: ${model.imageUrl}`)
                                console.log(`Pin Link: ${model.link}`)
                                console.log(`=====================`)

                                // Set source with error handling
                                pinImage.source = model.imageUrl
                            }

                            // Add to loading queue when delegate is created
                            Component.onCompleted: {
                                if (model.imageUrl && model.imageUrl.includes("pinimg.com")) {
                                    // Add with delay based on index for sequential loading
                                    Qt.callLater(function() {
                                        root.addToImageQueue(imageContainer)
                                    })
                                }
                            }

                            Component.onDestruction: {
                                shouldLoad = false
                                if (isLoading) {
                                    root.imageLoadComplete(false)
                                }
                            }

                            // CRASH-SAFE Image component
                            Image {
                                id: pinImage
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                cache: false // CRITICAL: Disable cache to prevent corruption
                                asynchronous: true

                                // STRICT source validation
                                source: ""

                                visible: status === Image.Ready && !imageContainer.hasError

                                onStatusChanged: {
                                    console.log(`Image status changed: ${status} for Pin ID: ${imageContainer.imageId} (${source})`)

                                    if (imageContainer.isLoading) {
                                        if (status === Image.Ready) {
                                            console.log(`✅ IMAGE LOADED SUCCESSFULLY - Pin ID: ${imageContainer.imageId}`)
                                            imageContainer.isLoading = false
                                            root.imageLoadComplete(true)
                                        } else if (status === Image.Error) {
                                            console.log(`❌ IMAGE LOAD ERROR - Pin ID: ${imageContainer.imageId} - URL: ${source}`)
                                            imageContainer.hasError = true
                                            imageContainer.isLoading = false
                                            source = "" // Clear problematic source
                                            root.imageLoadComplete(false)
                                        }
                                    }
                                }

                                // Rounded corners with safe masking
                                layer.enabled: visible && status === Image.Ready
                                layer.effect: OpacityMask {
                                    maskSource: Rectangle {
                                        width: pinImage.width
                                        height: pinImage.height
                                        radius: 12
                                    }
                                }

                                MouseArea {
                                    id: imageMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !imageContainer.hasError
                                    propagateComposedEvents: true

                                    onClicked: function(mouse) {
                                        // Only open link if heart button area wasn't clicked
                                        if (!heartButton.visible || !heartButton.contains(Qt.point(mouse.x - heartButton.x, mouse.y - heartButton.y))) {
                                            var url = model.link
                                            if (url && url !== "") {
                                                Qt.openUrlExternally(url)
                                            }
                                        }
                                    }

                                    onEntered: {
                                        if (!imageContainer.hasError) {
                                            parent.scale = 0.98
                                            heartButton.opacity = 1.0
                                            heartButton.visible = true
                                        }
                                    }

                                    onExited: {
                                        parent.opacity = 1.0
                                        parent.scale = 1.0
                                        // Only hide if not hovering over heart button
                                        if (!heartMouseArea.containsMouse) {
                                            heartButton.visible = false
                                        }
                                    }
                                }

                                Behavior on scale {
                                    NumberAnimation { duration: 200 }
                                }
                            }

                            // Heart save button - positioned in top-right corner with proper layering
                            Rectangle {
                                id: heartButton
                                width: 36
                                height: 36
                                radius: 18
                                color: root.savedPins[model.id] ? "#e74c3c" : (heartMouseArea.containsMouse ? "#ff8a8a" : "#ffffff")
                                opacity: 0.0
                                visible: false
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 6
                                z: 1000 // Very high z-index to ensure it's on top

                                // Prevent clicks from going through
                                enabled: visible

                                // Border for better visibility
                                border.color: "#cccccc"
                                border.width: 1

                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: 20
                                    height: 20
                                    source: "love"
                                    color: root.savedPins[model.id] ? "#ffffff" : "#e74c3c"
                                }

                                MouseArea {
                                    id: heartMouseArea
                                    anchors.fill: parent
                                    anchors.margins: -4 // Slightly larger hit area
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !root.savedPins[model.id] && parent.visible
                                    z: 1001 // Even higher z-index

                                    // Prevent event propagation to image behind
                                    propagateComposedEvents: false

                                    onClicked: function(mouse) {
                                        console.log("Heart button clicked for pin:", model.id)
                                        mouse.accepted = true // Consume the event
                                        root.savePinToProfile(model.id)

                                        // Provide immediate visual feedback
                                        heartButton.scale = 0.8
                                        scaleBackTimer.start()
                                    }

                                    onEntered: {
                                        heartButton.scale = 1.1
                                    }

                                    onExited: {
                                        heartButton.scale = 1.0
                                        // Keep button visible for a moment after mouse leaves
                                        if (!imageMouseArea.containsMouse) {
                                            hideHeartDelayTimer.start()
                                        }
                                    }

                                    onPressed: heartButton.scale = 0.9
                                    onReleased: heartButton.scale = heartMouseArea.containsMouse ? 1.1 : 1.0
                                }

                                // Smooth animations
                                Behavior on scale {
                                    NumberAnimation { duration: 150; easing.type: Easing.OutBack }
                                }

                                Behavior on color {
                                    ColorAnimation { duration: 200 }
                                }

                                Behavior on opacity {
                                    NumberAnimation { duration: 200 }
                                }

                                // Timer to scale back after click
                                Timer {
                                    id: scaleBackTimer
                                    interval: 200
                                    onTriggered: heartButton.scale = heartMouseArea.containsMouse ? 1.1 : 1.0
                                }

                                // Timer to hide heart button with delay
                                Timer {
                                    id: hideHeartDelayTimer
                                    interval: 300
                                    onTriggered: {
                                        if (!heartMouseArea.containsMouse && !imageMouseArea.containsMouse) {
                                            heartButton.visible = false
                                        }
                                    }
                                }

                                // Timer to hide heart button after saving (longer delay)
                                Timer {
                                    id: hideAfterSaveTimer
                                    interval: 3000 // Hide after 3 seconds
                                    onTriggered: {
                                        if (!heartMouseArea.containsMouse && !imageMouseArea.containsMouse) {
                                            heartButton.visible = false
                                        }
                                    }
                                }

                                // Show/hide with proper state management
                                onVisibleChanged: {
                                    if (visible) {
                                        opacity = 1.0
                                        scale = 1.0
                                        hideHeartDelayTimer.stop()
                                        hideAfterSaveTimer.stop()
                                    } else {
                                        opacity = 0.0
                                    }
                                }
                            }

                            // Enhanced placeholder with error state
                            Rectangle {
                                anchors.fill: parent
                                color: imageContainer.hasError ? "#4a1a1a" : PlasmaCore.Theme.backgroundColor || "#2a2a2a"
                                opacity: 1.0
                                radius: 12
                                visible: !pinImage.visible

                                PC.Label {
                                    anchors.centerIn: parent
                                    text: imageContainer.hasError ? "❌" : (imageContainer.isLoading ? "⏳" : "📷")
                                    font.pixelSize: Math.min(parent.width, parent.height) * 0.15
                                    color: imageContainer.hasError ? "#ff6b6b" : PlasmaCore.Theme.disabledTextColor || "#7f8c8d"
                                }

                                // Subtle loading animation
                                SequentialAnimation {
                                    running: imageContainer.isLoading && !imageContainer.hasError
                                    loops: Animation.Infinite
                                    PropertyAnimation {
                                        target: parent
                                        property: "opacity"
                                        to: 0.8
                                        duration: 1000
                                    }
                                    PropertyAnimation {
                                        target: parent
                                        property: "opacity"
                                        to: 1.0
                                        duration: 1000
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Placeholder / Error State
        Item {
            anchors.centerIn: parent
            width: parent.width * 0.85
            height: Math.min(300, parent.height * 0.8)
            visible: pinterestModel.count === 0 && root.lastError !== "" // Only show on error or explicit empty state, not loading
            
            Rectangle {
                anchors.fill: parent
                color: Kirigami.Theme.backgroundColor
                radius: 12
                opacity: 0.9
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 1
                
                layer.enabled: true
                layer.effect: DropShadow {
                    transparentBorder: true
                    radius: 8
                    samples: 16
                    color: Qt.rgba(0, 0, 0, 0.3)
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 15
                width: parent.width - 40

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignHCenter
                    source: root.lastError !== "" ? "dialog-error" : "pinterest"
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 64
                    opacity: 0.8
                }

                PC.Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.lastError !== "" ? "Oops!" : "Welcome"
                    font.bold: true
                    font.pixelSize: 22
                    color: Kirigami.Theme.textColor
                }

                PC.Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: root.lastError !== "" ? root.lastError : "Starting up..."
                    opacity: 0.7
                    font.pixelSize: 14
                }
                
                PC.Button {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Retry Connection"
                    icon.name: "view-refresh"
                    visible: root.lastError !== ""
                    onClicked: {
                        root.lastError = ""
                        root.fetchPinterestData()
                    }
                }
            }
        }
    }
    }

    // Compact representation
    compactRepresentation: PC.ToolButton {
        text: "📌"
        font.pixelSize: 16

        MouseArea {
            anchors.fill: parent
            onClicked: plasmoid.expanded = !plasmoid.expanded
        }
    }

    // CRASH PREVENTION: Clean initialization
    Component.onCompleted: {
        console.log("Pinterest widget initialized in SAFE MODE")
        console.log("Widget location:", Qt.resolvedUrl("."))
        console.log("Script path:", scriptPath)
        console.log("Save script path:", saveScriptPath)
        console.log("Max pins:", root.maxPins, "Max concurrent images:", maxConcurrentImages)

        // Delayed initial fetch to prevent startup crashes
        Qt.callLater(function() {
            fetchPinterestData()
        })
    }

    // CRASH PREVENTION: Clean shutdown
    Component.onDestruction: {
        console.log("Cleaning up Pinterest widget...")
        clearAllData()
    }
}
