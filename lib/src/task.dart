library tasks.src.task;

import 'dart:async';
import 'package:frappe/frappe.dart';
import 'package:tasks/src/priorities.dart';

/// A `Task` is an abstract class that's used to encapsulate code and data for processing work.
///
/// Since `Task` is abstract, you can either create a subclass or use a `BlockTask` to perform
/// the actual work.
abstract class Task<R> {
  final Completer<R> _completer = new Completer();
  _TaskState _state = _TaskState.pending;

  /// Indicates if the task is currently running.
  bool get isExecuting => _state == _TaskState.executing;

  /// Indicates if the task is waiting to be executed.
  bool get isPending => _state == _TaskState.pending;

  /// Indicates if the task completed, either successfully or unsuccessfully.
  bool get isFinished => _state == _TaskState.finished;

  /// Indicates if the task was cancelled.
  bool get isCancelled => _state == _TaskState.cancelled;

  /// A stream of events whenever the task's state changes.
  EventStream<Task<R>> get onStateChange => new EventStream(_onStateChange.stream);
  final StreamController<Task<R>> _onStateChange = new StreamController.broadcast();

  /// The execution priority for this task.
  ///
  /// The property represents the relative priority to other tasks in the same queue. Tasks
  /// that have a higher priority will be executed before tasks with a lower priority. In
  /// order to change the priority of a task, the current task must be cancelled and a new
  /// one created with the desired priority.
  final int priority;

  /// The tasks result.
  Future<R> get result => _completer.future;

  Task({this.priority: TaskPriority.normal});

  /// Marks the task as cancelled and calls [cancelWork] if the task is currently pending or
  /// executing.
  ///
  /// It's not guaranteed that the task's code will stop executing. Instead, it changes the
  /// task's state, removes it from its queue, and prevents it from being executed later.
  void cancel() {
    if (isExecuting || isPending) {
      _changeState(_TaskState.cancelled);
      cancelWork();
    }
  }

  /// Marks the task as executing and calls [performWork] if the task is currently pending.
  ///
  /// Subclasses must override [performWork] to implement the actual execution of the task.
  Future<R> execute() {
    if (isPending) {
      _changeState(_TaskState.executing);
      new Future(() => performWork())
          .then(_completer.complete)
          .catchError(_completer.completeError)
          .whenComplete(() => _changeState(_TaskState.finished));
    }
    return result;
  }

  /// Called when the task is cancelled to attempt to stop execution of the task.
  void cancelWork() {
    // Empty implementation.
  }

  /// Overridden by subclasses to perform the work for the task.
  ///
  /// Subclasses should return a future that completes with the result of the task. If the task
  /// erred, the task should complete with an error that triggers [Future.catchError].
  Future<R> performWork();

  void _changeState(_TaskState state) {
    _state = state;
    _onStateChange.add(this);
  }
}

class _TaskState {
  static const pending = const _TaskState(0);
  static const executing = const _TaskState(1);
  static const finished = const _TaskState(2);
  static const cancelled = const _TaskState(3);

  final int value;

  const _TaskState(this.value);
}
