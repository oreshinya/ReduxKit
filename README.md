# [![ReduxKit](https://cdn.rawgit.com/ReduxKit/ReduxKit/b3eb23d773f7c036d7567767884ed5cd50ff6b58/ReduxKit.svg)](https://github.com/ReduxKit/ReduxKit)

[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage) [![Cocoapods Compatible](https://img.shields.io/cocoapods/v/ReduxKit.svg)](https://img.shields.io/cocoapods/v/ReduxKit.svg) [![Platform](https://img.shields.io/cocoapods/p/ReduxKit.svg?style=flat)](http://cocoadocs.org/docsets/ReduxKit)

## Cross promotion / pollination

> [\#13](https://github.com/ReduxKit/ReduxKit/issues/13): [@Ben-G](https://github.com/Ben-G) has done an awesome job of developing an independent, very idiomatic, swift implementation of Redux as [Swift-Flow](https://github.com/Swift-Flow/Swift-Flow).
> 
> After a short discussion it's clear we all agree that collaboration and sharing of idea's will be beneficial to both projects. Go check it out. Feedback on both projects would be appreciated.

## Intro
ReduxKit is a swift implementation of the JavaScript [Redux](http://rackt.github.io/redux) library by Dan Abramov and the React Community. ReduxKit stays as close as possible to Redux while bringing in Swift ways of doing things where appropriate.

A thorough walk through and description of the framework can be found at the official Redux repository: [Redux](http://rackt.github.io/redux).

It is currently implemented in a few swift apps and is frequently updated. Additions, middleware and help will be very much appreciated! So if you're trying it out and have any suggestions - feel free to post an issue and I'll be on it.


## Installation

### [Carthage](https://github.com/Carthage/Carthage)

The easiest way to include ReduxKit is via Carthage:

**iOS 8.0 required**

Add ReduxKit to `Cartfile`
```
github "ReduxKit/ReduxKit" ~> 0.1
```

Run in terminal:
```bash
$ carthage update
```

### [CocoaPods](http://cocoapods.org)

Add ReduxKit to your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'

pod 'ReduxKit', '~> 0.1.3'
```

Then, run the following command:

```bash
$ pod install
```


## The Gist

A more advanced Swift example of the original [gist](https://github.com/rackt/redux/blob/master/README.md#the-gist)

```swift
import ReduxKit

/**
  * This is a simple standard action. The only requirement is that an action complies to
  * the Action protocol. The SimpleStandardAction contains a strongly typed rawPayload
  * property. The protocol automatically assigns the rawPayload to the Actions payload
  * property. This removes the necessity of type casting whenever working with actions in
  * a reducer.
  *
  * There's also the StandardAction protocol, that requires the struct to have an
  * initializer. This is required if the bindActionCreators helper is to be used.
  */
struct IncrementAction: SimpleStandardAction {
    let meta: Any? = nil
    let error: Bool = false
    let rawPayload: Int = 1
}

struct DecrementAction: SimpleStandardAction {
    let meta: Any? = nil
    let error: Bool = false
    let rawPayload: Int = 1
}

/**
  * This is a simple reducer. It is a pure function that follows the syntax
  * (state, action) -> state.
  * It describes how an action transforms the previous state into the next state.
  *
  * Instead of using the actions.type property - as is done in the regular Redux framework
  * we use the power of Swifts static typing to deduce the action.
  */
func counterReducer(previousState: Int?, action: Action) -> Int {
    // Declare the reducers default value
    let defaultValue = 0
    var state = previousState ?? defaultValue

    switch action {
        case let action as IncrementAction:
            return state + action.rawPayload
        case let action as DecrementAction:
            return state - action.rawPayload
        default:
            return state
    }
}

/**
  * The applications state. This should contain the state of the whole application.
  * When building larger applications, you can optionally assign complex structs to
  * properties on the AppState and handle them in the part of the application that
  * uses them.
  */
struct AppState {
  var count: Int!
}

/**
  * Create the applications reducer. While we could create a combineReducer function
  * we've currently chosen to allow reducers to be statically typed and accept
  * static states - instead of Any - which currently forces us to define the
  * application reducer as such. This could possibly be simplified with reflection.
  */
let applicationReducer = {(state: AppState? = nil, action: Action) -> AppState in

  return AppState(
    count: counterReducer(appState?.count, action: action),
    )
}

// Create application store. The second parameter is an optional default state.
let store = createStore(applicationReducer, nil)

let disposable = store.subscribe{ state in
  print(state)
}


store.dispatch(IncrementAction())
// {counter: 1}

store.dispatch(IncrementAction())
// {counter: 2}

store.dispatch(DecrementAction())
// {counter: 1}

// Dispose of the subscriber after use.
disposable.dispose()

```


## Types and the generic State

ReduxKit makes heavy use of Swift generics for simpler implementation and usage.

The only types used as generics are `State`, `Action` and `PayloadType`. Of which only `State` has no inference and will be commonly used. Because `typealias` does not support generics this does cause the framework source to become harder to read. Example `typealias` have been included privately in the source.

Once the root state type has been defined in your project, you may want to declare appropriate `typealias` mapping to the JavaScript Redux types.

```swift
// These two are already exported by ReduxKit as they do not use the State generic
// typealias Dispatch = Action -> Action
// typealias DispatchTransformer = Dispatch -> Dispatch

struct State {} // Can be named anything you like, as long as it's consistent in the typealias declarations

// Underscores are used where needed to prevent clashes with exported protocols. Again, naming is up to you.

typealias Store = ReduxKit.Store<State>

typealias Reducer = (previousState: State?, action: Action) -> State
typealias Subscriber = (updatedState: State) -> ()

typealias MiddlewareApi = Store
typealias Middleware = MiddlewareApi -> DispatchTransformer
typealias StoreCreator = (reducer: Reducer, initialState: State?) -> Store
typealias StoreEnhancer = (StoreCreator) -> StoreCreator

typealias StateStream = ReduxKit.StateStream<State>
typealias StreamFactory = (initialState: State) -> StateStream
```

Typealias not supporting generics can been seen most in the applyMiddleware function and makes for the best example of how to expand the ReduxKit examples out.

```swift
// How the applyMiddleware function would ideally be declared
func applyMiddleware(middleware: [Middleware])
	-> StoreEnhancer

// Expanding out (sans generic state):
func applyMiddleware(middleware: [MiddlewareApi -> DispatchTransformer])
	-> StoreCreator
	-> StoreCreator

func applyMiddleware(middleware: [Store -> DispatchTransformer])
	-> ((Reducer, State?) -> Store)
	-> ((Reducer, State?) -> Store)

func applyMiddleware(middleware: [Store -> DispatchTransformer])
	-> (((State?, Action) -> State, State?) -> Store)
	-> (((State?, Action) -> State, State?) -> Store)

// With the generic State
func applyMiddleware<State>(middleware: [(Store<State>) -> DispatchTransformer])
	-> (((State?, Action) -> State, State?) -> Store<State>)
	-> (((State?, Action) -> State, State?) -> Store<State>)
```



## API

Simplified and actual public functions and types:

### createStore

```swift
createStore(reducer: Reducer, state: State?) -> Store
createStore<State>(reducer: (State?, Action) -> State, state: State?) -> Store<State>
```

### createStreamStore

```swift
createStreamStore(streamFactory: StreamFactory, reducer: Reducer, state: State?) -> Store
createStreamStore<State>(
	streamFactory: State -> StateStream<State> = createSimpleStream,
	reducer: (State?, Action) -> State,
	state: State?)
	-> Store<State>

createStreamStore(streamFactory: StreamFactory) -> StoreCreator
createStreamStore<State>(streamFactory: State -> StateStream<State>)
	-> (reducer: (State?, Action) -> State, state: State?)
	-> Store<State>
```

### Disposable

```swift
protocol ReduxDisposable {
    var disposed: Bool { get }
    var dispose: () -> () { get }
}

struct SimpleReduxDisposable: ReduxDisposable {
    init(disposed: () -> Bool, dispose: () -> ())
}
```

### StateStream

```swift
struct StateStream {
    let dispatch: State -> ()
    let subscribe: Subscriber -> ReduxDisposable
    let getState: () -> State
    init(dispatch: State -> (), subscribe: Subscriber -> ReduxDisposable, getState: () -> State)
}
struct StateStream<State> {
    let dispatch: State -> ()
    let subscribe: (State -> ()) -> ReduxDisposable
    let getState: () -> State
    init(dispatch: State -> (), subscribe: (State -> ()) -> ReduxDisposable, getState: () -> State)
}
```

### StoreType


```swift
protocol StoreType {
    typealias State
    var dispatch: Dispatch { get }
    var subscribe: (Subscriber) -> ReduxDisposable { get }
    var getState: () -> State { get }
    init(dispatch: Dispatch, subscribe: (Subscriber) -> ReduxDisposable, getState: () -> State)
}
```


### Store

```swift
struct Store<State>: StoreType {
    let dispatch: Dispatch
    let subscribe: (Subscriber) -> ReduxDisposable
    let getState: () -> State
    var state: State
    init(dispatch: Dispatch, subscribe: (Subscriber) -> ReduxDisposable, getState: () -> State)
}

```

### applyMiddleware

```swift
func applyMiddleware(middleware: [Middleware]) -> StoreEnhancer
func applyMiddleware<State>(middleware: [Store<State> -> DispatchTransformer])
	-> (((State?, Action) -> State, State?) -> Store<State>)
	-> (((State?, Action) -> State, State?) -> Store<State>)
```

### bindActionCreators

```swift
func bindActionCreators<Action where Action: StandardAction>(type: Action.Type, dispatch: Dispatch)
    -> (payload: Action.PayloadType?)
    -> ()

```


## Available Middleware
+ [reduxSwift-Rx](https://github.com/ReduxKit/reduxSwift-rx)
  \- RxSwift utilities for ReduxSwift


## StateStreams

The ReduxKit Store is, at it's heart, a subscribable stream of states. You are likely already familiar with the concept from reactive frameworks. The two are so similar in fact that you will more than likely want to use ReduxKit with you favourite reactive framework.

The StateStream type allow does exactly that. Combined with a StateStreamFactory it allows ReduxKit to use almost any existing reactive framework as the state stream.

There is a state stream included with ReduxKit. It is not advisable to use it for anything more than examples as it's not thread or leak safe. The SimpleStateStream is just an array of subscribers.

ReduxKit has StateStream bindings available for:

- [RxSwift](https://github.com/ReduxKit/ReduxKitRxSwift)
- [ReactiveCocoa](https://github.com/ReduxKit/ReduxKitReactiveCocoa)
- [ReactiveKit](https://github.com/ReduxKit/ReduxKitReactiveKit)
- [SwiftBond](https://github.com/ReduxKit/ReduxKitBond)

TODO: Include examples and links to reactive stream providers.


## How can you help?

I am hoping to get a solid influx of middleware up and running for ReduxKit so we can change the way we do iOS development in the future. I am therefore welcoming pull requests, feature requests and suggestions. I want this library to be the best it can be and I can only do that with the help of the rest of you.

### TODO

The actual implementation of ReduxKit is fairly complete. More tooling is still required though.

- Test and release reactive framework bindings
- Create the TODO app to showcase ease of use
- Documentation: How thorough should we do it? Core principles are very well described by Dan in his docs.
- Devtools. This is where the power of redux really shines - being able to undo states when testing will make developing and debugging so much easier.


## License

MIT
