//
// Battery.swift
// SystemKit
//
// The MIT License
//
// Copyright (C) 2014-2017  beltex <https://github.com/beltex>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import IOKit
import Foundation
import os.log
import CocoaLumberjack

/**
Battery statistics for OS X, read-only.

http://www.apple.com/batteries/
 
*/
public struct SKBattery {
    //--------------------------------------------------------------------------
    // MARK: PUBLIC ENUMS
    //--------------------------------------------------------------------------

    /// Temperature units
    public enum TemperatureUnit {
        case celsius
        case fahrenheit
        case kelvin
    }

    //--------------------------------------------------------------------------
    // MARK: PRIVATE ENUMS
    //--------------------------------------------------------------------------

    /// Battery property keys. Sourced via 'ioreg -brc AppleSmartBattery'
    fileprivate enum Key: String {
        case ACPowered        = "ExternalConnected"
        case Amperage         = "Amperage"
        /// Current charge
        case CurrentCapacity  = "CurrentCapacity"
        case CycleCount       = "CycleCount"
        /// Originally DesignCapacity == MaxCapacity
        case DesignCapacity   = "DesignCapacity"
        case DesignCycleCount = "DesignCycleCount9C"
        case FullyCharged     = "FullyCharged"
        case IsCharging       = "IsCharging"
        /// Current max charge (this degrades over time)
        case MaxCapacity      = "MaxCapacity"
        case Temperature      = "Temperature"
        /// Time remaining to charge/discharge
        case TimeRemaining    = "TimeRemaining"
    }

    //--------------------------------------------------------------------------
    // MARK: PRIVATE PROPERTIES
    //--------------------------------------------------------------------------

    /// Name of the battery IOService as seen in the IORegistry
    fileprivate static let IOSERVICE_BATTERY = "AppleSmartBattery"

    fileprivate var service: io_service_t = 0

    //--------------------------------------------------------------------------
    // MARK: PUBLIC INITIALIZERS
    //--------------------------------------------------------------------------

    public init() { }

    //--------------------------------------------------------------------------
    // MARK: PUBLIC METHODS
    //--------------------------------------------------------------------------

    /**
    Open a connection to the battery.
    
    :returns: kIOReturnSuccess on success.
    */
    public mutating func open() -> kern_return_t {
        if service != 0 {
            #if DEBUG
                print("WARNING - \(#file):\(#function) - " +
                        "\(SKBattery.IOSERVICE_BATTERY) connection already open")
            #endif
            return kIOReturnStillOpen
        }

        service = IOServiceGetMatchingService(
            kIOMasterPortDefault,
            IOServiceNameMatching(SKBattery.IOSERVICE_BATTERY)
        )

        if service == 0 {
            #if DEBUG
                print("ERROR - \(#file):\(#function) - " +
                        "\(SKBattery.IOSERVICE_BATTERY) service not found")
            #endif
            return kIOReturnNotFound
        }

        return kIOReturnSuccess
    }

    /**
     * Returns true when a connection to the battery is open. Otherwise this function returns false.
     */
    public func connectionIsOpen() -> Bool {
        service != 0
    }

    /**
    Close the connection to the battery.
    
    :returns: kIOReturnSuccess on success.
    */
    public mutating func close() -> kern_return_t {
        let result = IOObjectRelease(service)
        service = 0     // Reset this incase open() is called again

        #if DEBUG
            if result != kIOReturnSuccess {
                print("ERROR - \(#file):\(#function) - Failed to close")
            }
        #endif

        return result
    }

    //--------------------------------------------------------------------------
    // MARK: PUBLIC METHODS - BATTERY
    //--------------------------------------------------------------------------

    /**
    Get the current capacity of the battery in mAh. This is essientally the
    current charge of the battery.
    
    https://en.wikipedia.org/wiki/Ampere-hour
    */
    public func currentCapacity() -> Int {
        guard let prop = IORegistryEntryCreateCFProperty(
            service,
            Key.CurrentCapacity.rawValue as CFString,
            kCFAllocatorDefault,
            0
            ) else {
                DDLogError("Failed to read the current capacity")
                return 0
        }
        
        guard let castValue = prop.takeUnretainedValue() as? Int else {
            DDLogError("Failed to cast the value to an Int")
            return 0
        }
        
        return castValue
    }

    /**
    Get the current max capacity of the battery in mAh. This degrades over time
    from the original design capacity.
    
    https://en.wikipedia.org/wiki/Ampere-hour
    */
    public func maxCapacity() -> Int {
        guard let prop = IORegistryEntryCreateCFProperty(
            service,
            Key.MaxCapacity.rawValue as CFString,
            kCFAllocatorDefault,
            0
            ) else {
                DDLogError("Failed to retrieve the mac capacity of the battery")
                return 0
        }
        
        guard let castValue = prop.takeUnretainedValue() as? Int else {
            DDLogError("Failed to cast the value to an Int")
            return 0
        }
        
        return castValue
    }

    /**
    Get the designed capacity of the battery in mAh. This is a static value.
    The max capacity will be equal to this when new, and as it degrades over
    time, be less than this.
    
    https://en.wikipedia.org/wiki/Ampere-hour
    */
    public func designCapacity() -> Int {
        guard let prop = IORegistryEntryCreateCFProperty(
            service,
            Key.DesignCapacity.rawValue as CFString,
            kCFAllocatorDefault,
            0
            ) else {
                DDLogError("Failed to read the design capacity of the battery")
                return 0
        }
        
        guard let castValue = prop.takeUnretainedValue() as? Int else {
            DDLogError("Failed to cast the value to an Int")
            return 0
        }
        
        return castValue
    }

    /**
    Get the current cycle count of the battery.

    https://en.wikipedia.org/wiki/Charge_cycle
    */
    public func cycleCount() -> Int {
        guard let prop = IORegistryEntryCreateCFProperty(
            service,
            Key.CycleCount.rawValue as CFString,
            kCFAllocatorDefault,
            0
            ) else {
                DDLogError("Failed to read the cycle count")
                return 0
        }
        
        guard let castValue = prop.takeUnretainedValue() as? Int else {
            DDLogError("Failed to cast the value to an Int")
            return 0
        }
        
        return castValue
    }

    /**
    Get the designed cycle count of the battery.
    
    https://en.wikipedia.org/wiki/Charge_cycle
    */
    public func designCycleCount() -> Int {
        guard let prop = IORegistryEntryCreateCFProperty(
            service,
            Key.DesignCycleCount.rawValue as CFString,
            kCFAllocatorDefault,
            0
            ) else {
                DDLogError("Failed to read the design cycle count of the battery")
                return 0
        }
        
        guard let castValue = prop.takeUnretainedValue() as? Int else {
            DDLogError("Failed to cast the value")
            return 0
        }
        
        return castValue
    }

    /**
    Is the machine powered by AC? Plugged into the charger.
    
    :returns: True if it is, false otherwise.
    */
    public func isACPowered() -> Bool {
        guard let prop = IORegistryEntryCreateCFProperty(
            service,
            Key.ACPowered.rawValue as CFString,
            kCFAllocatorDefault,
            0
            ) else {
                DDLogError("Failed to read whether the Battery is on AC")
                return false
        }

        guard let castValue = prop.takeUnretainedValue() as? Bool else {
            DDLogError("Failed to cast the value to a Bool")
            return false
        }

        return castValue
    }

    /**
    Is the battery charging?
    
    :returns: True if it is, false otherwise.
    */
    public func isCharging() -> Bool {
        guard let prop = IORegistryEntryCreateCFProperty(
            service,
            Key.IsCharging.rawValue as CFString,
            kCFAllocatorDefault,
            0
            ) else {
                DDLogError("Failed to read whether the battery is charging")
                return false
        }
        
        guard let castValue = prop.takeUnretainedValue() as? Bool else {
            DDLogError("Failed to cast the value to a Bool")
            return false
        }
        
        return castValue
    }

    /**
    Is the battery fully charged?
    
    :returns: True if it is, false otherwise.
    */
    public func isCharged() -> Bool {
        guard let prop = IORegistryEntryCreateCFProperty(
            service,
            Key.FullyCharged.rawValue as CFString,
            kCFAllocatorDefault,
            0
            ) else {
                DDLogError("Failed to read whether the battery is fully charged")
                return false
        }
        
        guard let castValue = prop.takeUnretainedValue() as? Bool else {
            DDLogError("Failed to cast the value to a Bool")
            return false
        }
        
        return castValue
    }

    /**
    What is the current charge of the machine? As seen in the battery status
    menu bar. This is the currentCapacity / maxCapacity.
    
    :returns: The current charge as a % out of 100.
    */
    public func charge() -> Double {
        let max = maxCapacity()
        let current = currentCapacity()
        
        if max == 0 {
            DDLogError("Maximum capacity is zero")
            return 0
        }
        
        return floor(Double(current) / Double(max) * 100.0)
    }

    /**
    The time remaining to full charge (if plugged into AC), or the time
    remaining to full discharge (running on battery). See also
    timeRemainingFormatted().
    
    :returns: Time remaining in minutes.
    */
    public func timeRemaining() -> Int {
        guard let prop = IORegistryEntryCreateCFProperty(
            service,
            Key.TimeRemaining.rawValue as CFString,
            kCFAllocatorDefault,
            0
            ) else {
                DDLogError("Failed to read the remaining time of the battery")
                return 0
        }
        
        guard let castValue = prop.takeUnretainedValue() as? Int else {
            DDLogError("Failed to cast the value to an Int")
            return 0
        }
        
        return castValue
    }

    /**
    Same as timeRemaining(), but returns as a human readable time format, as
    seen in the battery status menu bar.
    
    :returns: Time remaining string in the format <HOURS>:<MINUTES>
    */
    public func timeRemainingFormatted() -> String {
        let time = timeRemaining()
        return NSString(format: "%d:%02d", time / 60, time % 60) as String
    }

    /**
    Get the current temperature of the battery.
    
    "MacBook works best at 50° to 95° F (10° to 35° C). Storage temperature:
     -4° to 113° F (-20° to 45° C)." - via Apple
    
    http://www.apple.com/batteries/maximizing-performance/
    
    :returns: Battery temperature, by default in Celsius.
    */
    public func temperature(_ unit: TemperatureUnit = .celsius) -> Double {
        guard let prop = IORegistryEntryCreateCFProperty(
            service,
            Key.Temperature.rawValue as CFString,
            kCFAllocatorDefault,
            0
            ) else {
                DDLogError("Failed to raed the temperature")
                return 0
        }

        guard let castValue = prop.takeUnretainedValue() as? Double else {
            DDLogError("Failed to cast the value to a Double")
            return 0
        }
        
        var temperature = castValue / 100.0

        switch unit {
        case .celsius:
            // Do nothing - in Celsius by default
            // Must have complete switch though with executed command
            break
        case .fahrenheit:
            temperature = SKBattery.toFahrenheit(temperature)
        case .kelvin:
            temperature = SKBattery.toKelvin(temperature)
        }

        return ceil(temperature)
    }

    //--------------------------------------------------------------------------
    // MARK: PRIVATE HELPERS
    //--------------------------------------------------------------------------

    /**
    Celsius to Fahrenheit
    
    :param: temperature Temperature in Celsius
    :returns: Temperature in Fahrenheit
    */
    fileprivate static func toFahrenheit(_ temperature: Double) -> Double {
        // https://en.wikipedia.org/wiki/Fahrenheit#Definition_and_conversions
        return (temperature * 1.8) + 32
    }

    /**
    Celsius to Kelvin
    
    :param: temperature Temperature in Celsius
    :returns: Temperature in Kelvin
    */
    fileprivate static func toKelvin(_ temperature: Double) -> Double {
        // https://en.wikipedia.org/wiki/Kelvin
        return temperature + 273.15
    }
}
