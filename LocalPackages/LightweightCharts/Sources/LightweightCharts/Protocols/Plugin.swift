import Foundation

// MARK: - Base Plugin Protocol

/**
 Base protocol for all Lightweight Charts plugins.

 Plugins are attachable objects that extend chart functionality
 and can be detached (removed) when no longer needed.
 */
@MainActor
public protocol Plugin: AnyObject {
    /**
     Detaches (removes) the plugin from the chart.

     After calling this method, the plugin is removed from the chart
     and should no longer be used. This is an irreversible operation.
     */
    func detach()
}

// MARK: - Plugin with Options

/**
 Protocol for plugins that support runtime option updates.

 Plugins conforming to this protocol can have their options
 modified after creation without requiring detachment and recreation.
 */
@MainActor
public protocol PluginWithOptions: Plugin {
    /// The options type for this plugin
    associatedtype Options

    /**
     Applies new options to the plugin.

     - Parameter options: New options to apply to the plugin.
     Any subset of options can be specified; unspecified options
     retain their current values.
     */
    func applyOptions(options: Options)
}

// MARK: - Series Plugin

/**
 Protocol for plugins attached to a specific series.

 Series plugins are created on and operate within the context
 of a specific series instance.
 */
@MainActor
public protocol SeriesPlugin: Plugin {
    /**
     The series type this plugin is attached to.

     Must conform to both SeriesApi (for API access) and
     SeriesObject (for internal JavaScript bridge access).
     */
    associatedtype Series: SeriesApi & SeriesObject

    /**
     The series this plugin is attached to.

     This reference is weak to avoid retain cycles,
     as the series typically holds strong references to its plugins.
     */
    var series: Series? { get }
}

// MARK: - Pane Plugin

/**
 Protocol for plugins attached to a specific chart pane.

 Pane plugins are associated with a specific pane
 within the chart's pane hierarchy.
 */
@MainActor
public protocol PanePlugin: Plugin {
    /**
     Returns the current live index of the pane this plugin is attached to.

     - Returns: The pane's current index in the chart's `panes()` array.
     */
    func paneIndex() async throws(JavaScriptBridgeError) -> Int
}
