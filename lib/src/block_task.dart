library tasks.src.block_task;

import 'dart:async';
import 'package:tasks/src/task.dart';

class BlockTask<R> extends Task {
  final Function _block;

  BlockTask(R block(), {int priority: 0}) :
    _block = block,
    super(priority: priority);

  Future<R> performWork() {
    return new Future(() => _block());
  }
}
