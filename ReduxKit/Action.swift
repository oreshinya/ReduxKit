//
//  Action.swift
//  ReduxKit
//
//  Created by Aleksander Herforth Rendtslev on 03/11/15.
//  Copyright © 2015 Kare Media. All rights reserved.
//

/**
 *  Basic action structure
 */
public protocol Action {

    var type: String { get }

    var payload: Any? { get }

    var meta: Any? { get }

    var error: Bool { get }
}

public extension Action {

    /// Computed property that automatically fetches the actionType from the
    /// current action
    public var type: String { return "\(self.dynamicType.self)" }
}

/**
 *  Optional protocol used for when actions have to be created generically
 *
 *  It requires a initializer to be present
 */
public protocol StandardAction: SimpleStandardAction {

    init(payload: PayloadType?, meta: Any?, error: Bool)
}

/**
 *  This is the StandardAction which is the recommended protocol to use when
 *  implementing actions.
 *
 *  It is generic and expects a rawPayload of a generic type.
 */
public protocol SimpleStandardAction: Action {

    typealias PayloadType

    var rawPayload : PayloadType { get }
}

public extension SimpleStandardAction {

    /// Default implementation for payload
    public var payload: Any? { return rawPayload }
}


public struct DefaultAction: SimpleStandardAction {

    public let meta: Any? = nil

    public let error: Bool = false

    public let rawPayload: String = "$$ReduxKit-DefaultAction"

    public init() {}
}
