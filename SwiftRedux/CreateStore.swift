//
//  CreateStore.swift
//  SwiftRedux
//
//  Created by Aleksander Herforth Rendtslev on 09/11/15.
//  Copyright © 2015 Kare Media. All rights reserved.
//

import Foundation

func createRecursiveLock(name: String) -> NSRecursiveLock {
    let lock = NSRecursiveLock()
    lock.name = name
    return lock
}

public protocol Disposable {
    var isDisposed: Bool { get }
    func dispose()
}

/// A disposable that executes the given block upon disposing.
public final class BlockDisposable: Disposable {

    public var isDisposed: Bool {
        return handler == nil
    }

    private var handler: (() -> Void)?
    private let lock = createRecursiveLock("com.swift-bond.Bond.BlockDisposable")

    public init(_ handler: () -> Void) {
        self.handler = handler
    }

    public func dispose() {
        lock.lock()
        handler?()
        handler = nil
        lock.unlock()
    }
}

/// A disposable that disposes a collection of disposables upon disposing.
public final class CompositeDisposable: Disposable {

    public private(set) var isDisposed: Bool = false
    private var disposables: [Disposable] = []
    private let lock = createRecursiveLock("com.swift-bond.Bond.CompositeDisposable")

    public convenience init() {
        self.init([])
    }

    public init(_ disposables: [Disposable]) {
        self.disposables = disposables
    }

    public func addDisposable(disposable: Disposable) {
        lock.lock()
        if isDisposed {
            disposable.dispose()
        } else {
            disposables.append(disposable)
            self.disposables = disposables.filter { $0.isDisposed == false }
        }
        lock.unlock()
    }

    public func dispose() {
        lock.lock()
        isDisposed = true
        for disposable in disposables {
            disposable.dispose()
        }
        disposables = []
        lock.unlock()
    }
}

public func += (left: CompositeDisposable, right: Disposable) {
    left.addDisposable(right)
}

/// A simple wrapper around an optional that can retain or release given optional at will.
public final class Reference<T: AnyObject> {

    /// Encapsulated optional object.
    public weak var object: T?

    /// Used to strongly reference (retain) encapsulated object.
    private var strongReference: T?

    /// Creates the wrapper and strongly references the given object.
    public init(_ object: T) {
        self.object = object
        self.strongReference = object
    }

    /// Relinquishes strong reference to the object, but keeps weak one.
    /// If object it not strongly referenced by anyone else, it will be deallocated.
    public func release() {
        strongReference = nil
    }

    /// Re-establishes a strong reference to the object if it's still alive,
    /// otherwise it doesn't do anything useful.
    public func retain() {
        strongReference = object
    }
}

/// Abstract producer.
/// Can be given an observer (a sink) into which it should put (dispatch) events.
public protocol EventProducerType {

    /// Type of event objects or values that the observable generates.
    typealias EventType

    /// Registers the given observer and returns a disposable that can cancel observing.
    func observe(observer: EventType -> Void) -> Disposable
}

/// Enables production of the events and dispatches them to the registered observers.
public class EventProducer<Event>: EventProducerType {

    private var isDispatchInProgress: Bool = false
    private var observers: [Int64:Event -> Void] = [:]
    private var nextToken: Int64 = 0
    private let lock = createRecursiveLock("com.swift-bond.Bond.EventProducer")

    /// A composite disposable that will be disposed when the event producer is deallocated.
    public let deinitDisposable = CompositeDisposable()

    /// Used to manage lifecycle of the event producer when lifetime == .Managed.
    /// Captured by the producer sink. It will hold a strong reference to self
    /// when there is at least one observer registered.
    ///
    /// When all observers are unregistered, the reference will weakify its reference to self.
    /// That means the event producer will be deallocated if no one else holds a strong reference to it.
    /// Deallocation will dispose `deinitDisposable` and thus break the connection with the source.
    private weak var selfReference: Reference<EventProducer<Event>>? = nil

    private var latestValue: Event!

    /// The encapsulated value.
    public var value: Event {
        get { return latestValue }
        set { next(newValue) }
    }

    /// Creates a observable with the given initial value.
    public init(_ value: Event) {
        next(value)
    }

    /// Sends an event to the observers
    public func next(event: Event) {
        latestValue = event
        dispatchNext(event)
    }

    /// Registers the given observer and returns a disposable that can cancel observing.
    public func observe(observer: Event -> Void) -> Disposable {
        observer(latestValue)

        let eventProducerBaseDisposable = addObserver(observer)

        let observerDisposable = BlockDisposable { [weak self] in
            eventProducerBaseDisposable.dispose()

            if let unwrappedSelf = self {
                if unwrappedSelf.observers.count == 0 {
                    unwrappedSelf.selfReference?.release()
                }
            }
        }

        deinitDisposable += observerDisposable
        return observerDisposable
    }

    private func dispatchNext(event: Event) {
        guard !isDispatchInProgress else { return }

        lock.lock()
        isDispatchInProgress = true
        for (_, send) in observers {
            send(event)
        }
        isDispatchInProgress = false
        lock.unlock()
    }

    private func addObserver(observer: Event -> Void) -> Disposable {
        lock.lock()
        let token = nextToken
        nextToken = nextToken + 1
        lock.unlock()

        observers[token] = observer
        return EventProducerDisposable(eventProducer: self, token: token)
    }

    private func removeObserver(disposable: EventProducerDisposable<Event>) {
        observers.removeValueForKey(disposable.token)
    }

    deinit {
        deinitDisposable.dispose()
    }
}

public final class EventProducerDisposable<EventType>: Disposable {

    private weak var eventProducer: EventProducer<EventType>!
    private var token: Int64

    public var isDisposed: Bool {
        return eventProducer == nil
    }

    private init(eventProducer: EventProducer<EventType>, token: Int64) {
        self.eventProducer = eventProducer
        self.token = token
    }

    public func dispose() {
        if let eventProducer = eventProducer {
            eventProducer.removeObserver(self)
            self.eventProducer = nil
        }
    }
}

/**
 Will create a store with the state specified as

 - parameter reducer:      reducer description
 - parameter action:       action description
 - parameter initialState: initialState description

 - returns: return value description
 */
public func createStore(reducer: Reducer, state: State?) -> Store {

    let initialState: State = (state != nil) ? state! : reducer(state: state, action: DefaultAction())

    let producer = EventProducer(initialState)

    var isDispatching = false

    /**
     Will dispatch the given action to both reducers and middlewares

     - parameter action: the given action - that conforms to the protocol ActionType

     - returns: will return the action
     */
    func dispatch(action: Action) -> Action {
        do {
            try innerDispatch(action)
        } catch {
            print("Error dispatching. Are you dispatching from a reducer?")
        }

        return action
    }

    /**
     Will return the current state

     - returns: currentState
     */
    func getState() -> State {
        return producer.value
    }

    /**
     Will trigger onNext notifying al subscribers of the change

     - parameter action: the given Action

     - returns: the given action
     */
    func innerDispatch(action: Action) throws -> Action {

        /**
        *  the previous dispatch should be completed before the next one is initiated.
        */
        if (isDispatching) {
            throw StoreErrors.DispatchError
        }

        /**
        *  When the function is done running, reset the isDispatching variable
        */
        defer {
            isDispatching = false
        }

        isDispatching = true
        producer.next(reducer(state: producer.value, action: action))

        return action
    }

    /**
     Will subscribe to the stateSubjects onNext function

     - parameter onNext: Subscribe function

     - returns: will return the stateSubjects onNext function
     */
    func subscribe(onNext: State -> Void) -> Disposable {
        return producer.observe(onNext)
    }

    return StandardStore(dispatch: dispatch, getState: getState, subscribe: subscribe)

}

public enum StoreErrors: ErrorType {
    case DispatchError
}
