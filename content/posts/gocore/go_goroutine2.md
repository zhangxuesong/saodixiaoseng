---
title: "Go 语言及其执行规则 2"
date: 2020-12-17T16:59:29+08:00
toc: true
isCJKLanguage: true
tags: 
  - Go
---

## 怎样让主 `goroutine` 等待其他 `goroutine`

一旦主 `goroutine` 执行完毕，当前的 `Go` 程序就会结束运行，无论其他的 `goroutine` 是否已经在运行了。很多时候我们需要等待其他的 `goroutine` 的执行结果才让主 `goroutine` 结束运行，来看下怎么做：

```go
for i := 0; i < 10; i++ {
    go func() {
        fmt.Println(i)
    }()
}

time.Sleep(time.Millisecond * 500)
```

最简单粗暴的方法就是让程序在这里睡一会儿，等待其他 `goroutine` 执行完成后再结束运行，但是这个时间不好控制。

```go
num := 10
sign := make(chan struct{}, num)

for i := 0; i < num; i++ {
    go func() {
        fmt.Println(i)
        sign <- struct{}{}
    }()
}

for j := 0; j < num; j++ {
    <-sign
}
```

使用通道，每个手动启用的 `goroutine` 即将运行完毕的时候，我们都要向该通道发送一个值。注意，这些发送表达式应该被放在它们的 `go` 函数体的最后面。对应的，我们还需要在 `main` 函数的最后从通道接收元素值，接收的次数也应该与手动启用的 `goroutine` 的数量保持一致。

这里有一个细节。在声明通道 `sign` 的时候是以 `chan struct{}` 作为其类型的。其中的类型字面量 `struct{}` 有些类似于空接口类型 `interface{}`，它代表了既不包含任何字段也不拥有任何方法的空结构体类型。

`struct{}` 类型值的表示法只有一个，即：`struct{}{}`。并且，它占用的内存空间是 0 字节。确切地说，这个值在整个 `Go` 程序中永远都只会存在一份。虽然我们可以无数次地使用这个值字面量，但是用到的却都是同一个值。

当我们仅仅把通道当作传递某种简单信号的介质的时候，用 `struct{}` 作为其元素类型是再好不过的了。

使用 `sync.WaitGroup`

## 怎样让多个手动启用的 `goroutine` 按照既定顺序执行

首先，需要把 `i` 传入 `go` 函数，保证每个 `goroutine` 可以拿到一个唯一的整数。

```go
var count uint32
trigger := func(i uint32, fn func()) {
    for {
        if n := atomic.LoadUint32(&count); n == i {
            fn()
            atomic.AddUint32(&count, 1)
            break
        }
        time.Sleep(time.Nanosecond)
    }
}
for i := uint32(0); i < 10; i++ {
    go func(i uint32) {
        fn := func() {
            fmt.Println(i)
        }
        trigger(i, fn)
    }(i)
}
trigger(10, func() {})
```

`go` 函数中声明了一个匿名函数，并把它赋给了变量 `fn`，该函数只是打印参数 `i` 的值。

之后调用了 `trigger` 函数，并把参数 `i` 和 变量 `fn` 作为参数传给了它。

`trigger` 函数接受两个参数，一个是 `uint32` 类型的参数 `i`，一个是 `func()` 类型的参数 `fn`，它会不断的获取变量 `count` 的值，并判断该值是否与参数 `i` 的值相同。如果相同，那么立即调用参数 `fn` 代表的函数，然后把 `count` 的值加 1，最后显示的退出当前循环。否则就让当前 `goroutine` 睡一个纳秒再进入下一个迭代。

这里对变量 `count` 的操作都是原子性的。由于 `trigger` 函数会被多个 `goroutine` 并发调用，所以它用到的非本地变量 `count` 被多个用户级线程公用了。因此，对它的操作就产生了竞态条件（race condition），这破坏了程序的并发安全性。所以我们总是应该对这样的操作加以保护，在 `sync/atomic` 包中声明了很多用于原子操作的函数。

因为选用的原子操作的函数对被操作的数值有类型约束，所以这里的类型都改成了 `uint32`。

这里要做的就是让 `count` 变量称为一个信号，它的值总是下一个可以调用打印函数的 `go` 函数的序号。这个序号就是启用 `goroutine` 时的那个当次迭代的序号，也因为如此，`go` 函数实际的运行顺序才会与 `go` 语句的执行顺序完全一致。此外，这里的 `trigger` 函数实现了一种自旋（spinning）。除非发现条件以满足，否则会不断的进行检查。

最后，因为依然想让主 `goroutine` 最后一个运行完毕，所以这里加了一行代码 `trigger(10, func() {})`。当所有手动启动的 `goroutine` 都运行完毕后，`count` 一定会变成 10，所以把 10 作为第一个参数，然后又不想打印这个 10，所以传了个什么都不做的函数。

通过上面这个例子，使得异步发起的 `go` 函数得到了同步执行。