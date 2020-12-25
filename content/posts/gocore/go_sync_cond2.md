---
title: "条件变量 sync.Cond 2"
date: 2020-12-24T15:04:15+08:00
toc: true
isCJKLanguage: true
tags: 
  - Go
---

## 条件变量的 Wait方法做了什么

条件变量的 Wait 方法主要做了四件事：

- 把调用它的 goroutine 加入到当前条件变量的通知队列中。
- 解锁当前条件变量基于的互斥锁。
- 让当前的 goroutine 处于等待状态，等到通知到来时再决定是否要唤醒它。这时，goroutine 会阻塞在调用 Wait 方法的那行代码上。
- 如果通知到来并决定唤醒 goroutine，那面唤醒它之后重新锁定当前条件变量基于的互斥锁。当前的 goroutine 就可以继续执行后面的代码了。

条件变量的 Wait 方法在阻塞当前 goroutine 之前，会解锁它基于的互斥锁，所以在调用 Wait 方法之前，我们必须先锁定那个互斥锁，否则调用 Wait 方法时就会引发一个不可恢复的 panic。

```go
// Wait atomically unlocks c.L and suspends execution
// of the calling goroutine. After later resuming execution,
// Wait locks c.L before returning. Unlike in other systems,
// Wait cannot return unless awoken by Broadcast or Signal.
//
// Because c.L is not locked when Wait first resumes, the caller
// typically cannot assume that the condition is true when
// Wait returns. Instead, the caller should Wait in a loop:
//
//    c.L.Lock()
//    for !condition() {
//        c.Wait()
//    }
//    ... make use of condition ...
//    c.L.Unlock()
//
func (c *Cond) Wait() {
	c.checker.check()
	t := runtime_notifyListAdd(&c.notify)
	c.L.Unlock()
	runtime_notifyListWait(&c.notify, t)
	c.L.Lock()
}
```

所以说，如果条件变量的 Wait 不先解锁互斥锁的话，只会造成两种后果：不是当前程序因 panic 而崩溃，就是相关的 goroutine 全面阻塞。

## 为什么要用 for 而不是 if 来包裹 Wait 方法

很显然，if 语句只会对共享资源的状态检查一次，而 for 语句可以多次检查。如果一个 goroutine 因收到通知而被唤醒，却发现共享资源的状态依然不符合它的要求，那面就应该再次调用 Wait 方法继续等待下次通知。

有几种场景可能发生这样的情况：

1. 有多个 goroutine 在等待共享资源的同一种状态。虽然有多个 G 同时等待，但每次只能成功一个。因为条件变量的 Wait 方法会在当前的 G 醒来后重新锁定互斥锁。那别的 G 进入临界区后发现状态依然不是它们想要的，于是只能继续等待。
2. 共享资源的状态不是两个而是多个。这种情况下，由于状态在每次改变后的结果只可能有一个，所以，在设计合理的前提下，单一的结果一定不可能满足所有 goroutine 的条件。那些未被满足的 G 显然还需要继续等待和检查。
3. 共享资源状态有两个，并且每种状态都只有一个 G 在关注。在一些多 CPU 核心的计算机系统中，即使没收到条件变量的通知，调用 Wait 方法的 G 也是有可能被唤醒的。这是由计算机硬件层面决定的，即使操作系统本身提供的条件变量也会如此。

## 条件变量的 Signal 和 Broadcast 方法有什么区别

条件变量的 Signal 和 Broadcast 方法都是用来发送通知的，不同的是，前者的通知只会唤醒一个因此而等待的 G，而后者的通知会唤醒所有因此而等待的 G。

条件变量的 Wait 方法总会把当前的 G 添加到通知队列的队尾，而它的 Signal 方法总会通知队列的队首开始查找可被唤醒的 G。所以 Signal 唤醒的一般都是最早等待的那个。

此外，与 Wait 方法不同，条件变量的 Signal 和 Broadcast 方法并不需要在互斥锁的保护下执行。我们最好在解锁条件变量基于的那个互斥锁之后再去调用它的这两个方法。这更有利于程序运行的效率。

最后，条件变量的通知具有即时性。就是说发送通知的时候没有 G 因此而等待时，通知就会被直接丢弃。在这之后开始等待的 G 只能被后续通知唤醒。

