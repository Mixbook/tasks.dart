library tasks.src.task_queue;

import 'dart:async';
import 'package:tasks/src/task.dart';
import 'package:collection/collection.dart';

/// A `TaskQueue` regulates the execution of [Task]s.
///
/// The number of tasks that can run in parallel can be controlled by the queue's
/// concurrency count. By default, a task queue executes tasks sequentually and has a
/// [concurrencyCount] of 1.
///
/// Tasks are executed according to their priority. Tasks that have a higher priority
/// will be executed before tasks with a lower priority. If the priority of a task needs
/// to be changed, the old task must be cancelled and a new one inserted.
///
/// Tasks remain in the queue until the task finishes or is cancelled.
class TaskQueue<R> {
  final int _concurrencyCount;
  final _queue = new HeapPriorityQueue<_QueuedTask<R>>((a, b) => a.compareTo(b));
  final _running = new Set<_QueuedTask<R>>();
  var _state = _TaskQueueState.paused;

  /// The ordered list of tasks that are currently pending execution.
  Iterable<Task<R>> get tasks => _queue.toList()
      .map((queuedTask) => queuedTask.task)
      .where((task) => task.isPending);

  /// The number of tasks that are pending execution.
  int get length => tasks.length;

  /// Indicates if the queue is currently paused.
  bool get isPaused => _state == _TaskQueueState.paused;

  /// Indicates if the queue is currently running.
  bool get isRunning => _state == _TaskQueueState.running;

  int _taskId = 0;

  /// Creates a new running queue that runs the number of tasks indicated by [concurrencyCount].
  TaskQueue({int concurrencyCount: 1}) : _concurrencyCount = concurrencyCount {
    start();
  }

  /// Creates a new paused queue that will run the number of tasks indicated by [concurrencyCount]
  /// when the queue is started.
  factory TaskQueue.paused({int concurrencyCount: 1}) {
    return new TaskQueue(concurrencyCount: concurrencyCount)..pause();
  }

  /// Adds a [task] to this queue, and executes it if possible.
  Future<R> queue(Task<R> task) {
    if (task.isPending) {
      _queue.add(new _QueuedTask(_getNextTaskId(), this, task));
      _runMax();
    }
    return task.result;
  }

  /// Starts the execution of tasks in the queue.
  void start() {
    if (isPaused) {
      _state = _TaskQueueState.running;
      _runMax();
    }
  }

  /// Prevents the execution of any tasks that are currently queued.
  void pause() {
    if (isRunning) {
      _state = _TaskQueueState.paused;
    }
  }

  void _runNext() {
    var queuedTask = _queue.removeFirst();

    if (queuedTask.task.isPending) {
      queuedTask.task.execute();
      _running.add(queuedTask);
    }
  }

  void _runMax() {
    while (isRunning && _queue.isNotEmpty && _running.length < _concurrencyCount) {
      _runNext();
    }
  }

  /// Tasks need to be given an ID in order to remove them from the HeapPriorityQueue.
  /// The HeapPriorityQueue considers two elements identical if they have the same
  /// priority, so it's possible to unintentionally remove the wrong task if tasks have
  /// the same priority.
  int _getNextTaskId() => ++_taskId;
}

class _TaskQueueState {
  static const paused = const _TaskQueueState(0);
  static const running = const _TaskQueueState(1);

  final int value;

  const _TaskQueueState(this.value);
}

class _QueuedTask<R> implements Comparable<_QueuedTask<R>> {
  final int id;
  final TaskQueue<R> taskQueue;
  final Task<R> task;

  StreamSubscription _onStateChangeSubscription;

  _QueuedTask(this.id, this.taskQueue, this.task) {
    _onStateChangeSubscription = task.onStateChange.listen((_) => _handleStateChange());
  }

  int compareTo(_QueuedTask<R> other) {
    // The HeapPriorityQueue orders elements in ascending order. Since we want tasks that
    // have a higher priority to be executed first, we need to invert their priorities to
    // order them descending.
    var compareResult = Comparable.compare(-task.priority, -other.task.priority);

    // If the elements have the same priority, then order them ascending by their ID.
    if (compareResult == 0) {
      return Comparable.compare(id, other.id);
    } else {
      return compareResult;
    }
  }

  void _cleanup() {
    _onStateChangeSubscription.cancel();
  }

  void _handleStateChange() {
    if (task.isCancelled || task.isFinished) {
      if (taskQueue._running.contains(this)) {
        taskQueue._running.remove(this);
      } else {
        taskQueue._queue.remove(this);
      }

      _cleanup();
      taskQueue._runMax();
    }
  }
}
