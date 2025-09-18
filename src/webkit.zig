//! Artemis WebKit - RippleJS-inspired reactive web UI framework
//! 
//! This module provides a comprehensive web framework for building reactive
//! user interfaces that can run both natively and in WebAssembly browsers.
//!
//! Key features:
//! - Reactive component system inspired by RippleJS
//! - WebAssembly compilation support  
//! - Browser API bindings
//! - Virtual DOM with efficient diffing
//! - State management and event handling
//! - CSS-in-Zig styling system

const std = @import("std");
const artemis = @import("artemis-engine");
const gui = @import("artemis-gui");

pub const Component = @import("component.zig");
pub const ReactiveSystem = @import("reactive.zig");
pub const WebApp = @import("web_app.zig");
pub const DOM = @import("dom.zig");
pub const Events = @import("events.zig");
pub const Style = @import("style.zig");
pub const Router = @import("router.zig");

/// WebKit version information
pub const VERSION = "1.0.0";

/// WebKit configuration
pub const Config = struct {
    /// Enable development mode with hot-reloading and debugging
    development: bool = false,
    
    /// Enable WASM-specific optimizations
    wasm_optimized: bool = false,
    
    /// Maximum component tree depth
    max_component_depth: u32 = 256,
    
    /// Virtual DOM update batch size
    batch_size: u32 = 100,
    
    /// Default styling theme
    theme: Style.Theme = Style.Theme.default(),
};

/// WebKit runtime context
pub const WebKit = struct {
    allocator: std.mem.Allocator,
    config: Config,
    
    // Core systems
    reactive_system: ReactiveSystem,
    dom: DOM,
    router: Router,
    
    // State management
    global_state: std.HashMap([]const u8, std.json.Value, std.HashMap.StringContext, std.hash_map.default_max_load_percentage),
    
    // Event handling
    event_listeners: std.ArrayList(Events.EventListener),
    
    // Component registry
    components: std.HashMap([]const u8, *Component, std.HashMap.StringContext, std.hash_map.default_max_load_percentage),
    
    // Performance tracking
    render_time_ms: f64 = 0.0,
    component_count: u32 = 0,
    
    const Self = @This();
    
    /// Initialize WebKit with configuration
    pub fn init(allocator: std.mem.Allocator, config: Config) !Self {
        return Self{
            .allocator = allocator,
            .config = config,
            .reactive_system = try ReactiveSystem.init(allocator),
            .dom = try DOM.init(allocator),
            .router = try Router.init(allocator),
            .global_state = std.HashMap([]const u8, std.json.Value, std.HashMap.StringContext, std.hash_map.default_max_load_percentage).init(allocator),
            .event_listeners = std.ArrayList(Events.EventListener).init(allocator),
            .components = std.HashMap([]const u8, *Component, std.HashMap.StringContext, std.hash_map.default_max_load_percentage).init(allocator),
        };
    }
    
    /// Clean up WebKit resources
    pub fn deinit(self: *Self) void {
        self.reactive_system.deinit();
        self.dom.deinit();
        self.router.deinit();
        self.global_state.deinit();
        self.event_listeners.deinit();
        
        // Clean up components
        var component_iterator = self.components.iterator();
        while (component_iterator.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        self.components.deinit();
    }
    
    /// Create a new reactive component
    pub fn createComponent(self: *Self, name: []const u8, component_type: Component.Type) !*Component {
        var component = try Component.init(self.allocator, component_type);
        try self.components.put(name, component);
        self.component_count += 1;
        return component;
    }
    
    /// Mount a component to the DOM
    pub fn mount(self: *Self, component: *Component, target: []const u8) !void {
        try self.dom.mount(component, target);
        try self.reactive_system.track(component);
    }
    
    /// Update the application state and trigger re-renders
    pub fn update(self: *Self) !void {
        const start_time = std.time.nanoTimestamp();
        
        // Update reactive system
        try self.reactive_system.update();
        
        // Process DOM updates
        try self.dom.update();
        
        // Handle routing
        try self.router.update();
        
        const end_time = std.time.nanoTimestamp();
        self.render_time_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;
    }
    
    /// Set global application state
    pub fn setState(self: *Self, key: []const u8, value: std.json.Value) !void {
        try self.global_state.put(key, value);
        try self.reactive_system.notify(key);
    }
    
    /// Get global application state
    pub fn getState(self: *Self, key: []const u8) ?std.json.Value {
        return self.global_state.get(key);
    }
    
    /// Register an event listener
    pub fn addEventListener(self: *Self, event: Events.EventType, callback: Events.EventCallback) !void {
        const listener = Events.EventListener{
            .event_type = event,
            .callback = callback,
        };
        try self.event_listeners.append(listener);
    }
    
    /// Dispatch an event
    pub fn dispatchEvent(self: *Self, event: Events.Event) !void {
        for (self.event_listeners.items) |listener| {
            if (listener.event_type == event.type) {
                try listener.callback(event);
            }
        }
    }
    
    /// Navigate to a new route
    pub fn navigate(self: *Self, path: []const u8) !void {
        try self.router.navigate(path);
    }
    
    /// Get performance metrics
    pub fn getMetrics(self: *const Self) Metrics {
        return Metrics{
            .render_time_ms = self.render_time_ms,
            .component_count = self.component_count,
            .dom_node_count = self.dom.getNodeCount(),
            .memory_usage_bytes = self.getAllocatedBytes(),
        };
    }
    
    fn getAllocatedBytes(self: *const Self) usize {
        // This would need to be implemented with allocator tracking
        // For now, return an estimate
        return self.component_count * 1024; // Rough estimate
    }
};

/// Performance and debugging metrics
pub const Metrics = struct {
    render_time_ms: f64,
    component_count: u32,
    dom_node_count: u32,
    memory_usage_bytes: usize,
    
    pub fn print(self: Metrics) void {
        std.debug.print("WebKit Metrics:\n");
        std.debug.print("  Render time: {d:.2}ms\n", .{self.render_time_ms});
        std.debug.print("  Components: {}\n", .{self.component_count});
        std.debug.print("  DOM nodes: {}\n", .{self.dom_node_count});
        std.debug.print("  Memory usage: {} bytes\n", .{self.memory_usage_bytes});
    }
};

/// Convenience function to create a WebKit application
pub fn createApp(allocator: std.mem.Allocator, config: Config) !WebKit {
    return WebKit.init(allocator, config);
}

/// WASM-specific initialization for browser environments
pub fn initWasm(allocator: std.mem.Allocator) !WebKit {
    var config = Config{
        .wasm_optimized = true,
        .development = false,
    };
    
    var webkit = try WebKit.init(allocator, config);
    
    // Initialize browser bindings
    try initBrowserBindings(&webkit);
    
    return webkit;
}

/// Initialize browser API bindings for WASM
fn initBrowserBindings(webkit: *WebKit) !void {
    // This would initialize WebGL, DOM APIs, etc.
    // For now, just a placeholder
    _ = webkit;
}

// Export main interface for C/WASM interop
export fn webkit_create() ?*WebKit {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    
    const webkit = createApp(allocator, Config{}) catch return null;
    
    // Allocate on heap for C interop
    const webkit_ptr = allocator.create(WebKit) catch return null;
    webkit_ptr.* = webkit;
    return webkit_ptr;
}

export fn webkit_destroy(webkit: ?*WebKit) void {
    if (webkit) |ptr| {
        ptr.deinit();
        // Would need to track allocator to properly free
    }
}

export fn webkit_update(webkit: ?*WebKit) c_int {
    if (webkit) |ptr| {
        ptr.update() catch return -1;
        return 0;
    }
    return -1;
}

// Tests
test "webkit_initialization" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    var webkit = try WebKit.init(allocator, Config{});
    defer webkit.deinit();
    
    try testing.expect(webkit.component_count == 0);
    try testing.expect(webkit.render_time_ms == 0.0);
}

test "component_creation" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    var webkit = try WebKit.init(allocator, Config{});
    defer webkit.deinit();
    
    const component = try webkit.createComponent("test", Component.Type.div);
    try testing.expect(webkit.component_count == 1);
    try testing.expect(component != null);
}