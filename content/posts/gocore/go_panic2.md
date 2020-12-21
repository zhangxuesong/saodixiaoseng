---
title: "Go 异常处理 2"
date: 2020-12-21T16:22:57+08:00
toc: true
isCJKLanguage: true
tags: 
  - Go
---

## 怎样让 `panic` 包含一个值，应该让它包含什么值

在调用 `panic` 函数时，把某个值作为参数传给该函数就可以了。由于 `panic` 函数的唯一一个参数是空接口类型的，从语法上讲，它可以接受任何类型的值。但是我们最好传入 `error` 类型的错误值，或者其他可以被有效序列化的值。这里的有效序列化指的是可以更易读的去表示形式转换。

对于 `fmt` 包下的各种打印函数来说，`error` 类型值的 `Error` 方法与其他类型值的 `String` 函数是等价的，它们的唯一结果都是 `string` 类型的。我们在通过占位符 `%s` 打印这些值的时候，它们的字符串表示形式分别都是这两种方法产出的。

一旦程序异常了，我们就一定要把异常的相关信息记录下来，这通常都是记录到程序日志里。我们在排查错误时，首先要做的就是查看和解读程序日志。而最常用也是最方便的日志记录方式，就是记录下相关值的字符串表示形式。

所以，如果你觉得某个值可能被记到日志里，那么就应该为它关联 `String` 方法。如果这个值是 `error` 类型的，那么让它的 `Error` 方法返回你为它定制的字符串表示形式就可以了。

对于 `fmt.Sprintf`，以及 `fmt.Fprintf` 这类可以格式化输出参数的函数，它们本身就可以被用来输出值的某种表示形式。不过，它们在功能上肯定不如我们自己定义的 `String` 方法或者 `Error` 方法。因此，为不同的数据类型分别编写这两种方法总是首选。

```go
package main

import (
	"errors"
	"fmt"
)

func main() {
	fmt.Println("Enter function main.")
	caller()
	fmt.Println("Exit function main.")
}

func caller() {
	fmt.Println("Enter function caller.")
	panic(errors.New("something wrong")) // 正例。
	panic(fmt.Println)                   // 反例。
	fmt.Println("Exit function caller.")
}
```

同理，在程序崩溃的时候，将 `panic` 包含的那个值字符串表示形式打印出来。另外还可以施加某种保护措施，避免程序崩溃。这时，`panic` 包含的值会被取出然后打印出来或者记录到日志里。

## `panic` 保护措施

`Go` 语言的内建函数 `recover` 专用于恢复 `panic`，或者说平息运行时恐慌。`recover` 函数无需任何参数，并且会返回一个空接口类型的值。

如果用法正确，这个值实际上就是即将恢复的 `panic` 包含的值。并且，如果这个 `panic` 是因我们调用 `panic` 函数而引发的，那么该值同时也会是我们此次调用 `panic` 函数时，传入的参数副本。请注意，这里强调用法的正确。

```go
package main

import (
	"errors"
	"fmt"
)

func main() {
	fmt.Println("Enter function main.")
	// 引发panic。
	panic(errors.New("something wrong"))
	p := recover()
	fmt.Printf("panic: %s\n", p)
	fmt.Println("Exit function main.")
}
```

在上面这个 `main` 函数里，我们先通过调用 `panic` 引发了一个 `panic`，紧接着想调用 `recover` 函数恢复这个 `panic`。可是结果依旧崩溃，这个 `recover` 函数调用并不会起到任何作用，甚至都没有机会执行。

因为 `panic` 一旦发生，控制权就会迅速的沿着调用栈的反方向传播。所以，在 `panic` 函数调用之后的代码，根本就没有执行的机会。

即使我们把 `recover` 函数提前，就是说先调用 `recover` 函数，在调用 `panic` 函数也是不行的。如果我们在调用 `recover` 时根本没发生 `panic`，那么该函数不会做任何事，只会返回一个 `nil`。

`defer` 语句就是被用来延迟执行代码的。它将代码延迟到该语句所在函数即将执行结束的那一刻，无论结束执行的原因是什么。与 `go` 语句类似，一个 `defer` 语句总是由一个 `defer` 关键字和一个调用表达式组成。

这里存在一些限制，有一些调用表达式是不能出现在这里的，包括：针对 `Go` 语言内建函数的调用表达式，以及针对 `unsafe` 包中的函数调用表达式。对于 `go` 语句中的调用表达式，限制也是一样的。另外，在这里被调用的函数可以是有名称的，也可以是匿名的。我们可以把这里的函数叫做 `defer` 函数或者延迟函数。注意，被延迟执行的是 `defer` 函数，而不是 `defer` 语句。

无论结束执行的原因是什么，其中的 `defer` 函数都会在它即将结束执行的那一刻执行。即使导致它执行结束的原因是一个 `panic` 也会是这样。所以，我们需要联用 `defer` 语句和 `recover` 函数调用，才能够恢复一个已经发生的 `panic`。

```go
package main

import (
	"errors"
	"fmt"
)

func main() {
	fmt.Println("Enter function main.")
	defer func() {
		fmt.Println("Enter defer function.")
		if p := recover(); p != nil {
			fmt.Printf("panic: %s\n", p)
		}
		fmt.Println("Exit defer function.")
	}()
	// 引发panic。
	panic(errors.New("something wrong"))
	fmt.Println("Exit function main.")
}
```

在这个 `main` 函数中，我们首先编写了一条 `defer` 语句，并在 `defer` 函数中调用了 `recover` 函数。仅当调用的结果不为 `nil` 时，也就是说只有 `panic` 确实已发生时，才会打印一行以 `panic:` 为前缀的内容。

紧接着调用了 `panic` 函数，并传入了一个 `error` 类型值。这里注意尽量把 `defer` 语句写在函数体的开始处，因为在引发 `panic` 的语句之后的所有语句，都不会有任何机会执行。只有这样，`defer` 函数中的 `recover` 函数调用才会拦截，并恢复 `defer` 语句所属的函数及其调用的代码中所发生的 `panic`。

## 当有多条 `defer` 时的执行顺序

在同一个函数中，`defer` 函数调用的执行顺序与他们分别所属的 `defer` 语句的出现顺序（更严谨的说，是执行顺序）完全相反。

当一个函数即将结束执行时，其中的写在最下面的 `defer` 函数调用会被先执行，其次是写在它上面、与它距离最近的那个 `defer` 函数调用，以此类推，最上边的 `defer` 会最后一个执行。

如果函数中有一条 `for` 语句，并且这条 `for` 语句中包含了一条 `defer` 语句，那么，显然这条 `defer` 语句的执行次数就取决于 `for` 语句的迭代次数。

在 `defer` 语句每次执行的时候，`Go` 语言会把它携带的 `defer` 函数及其参数值另行存储到一个链表中。这个链表与该 `defer` 语句所属的函数是对应的，它是先进后出的（FILO），相当于一个栈。

在需要执行某个函数中的 `defer` 函数调用时，`Go` 语言会先拿到对应的链表，然后从中一个个的取出 `defer` 函数及其参数值，并逐个执行调用。这也是上述的：`defer` 函数调用与其所属的 `defer` 语句的执行顺序完全相反的原因了。

```go
package main

import "fmt"

func main() {
	defer fmt.Println("first defer")
	for i := 0; i < 3; i++ {
		defer fmt.Printf("defer in for [%d]\n", i)
	}
	defer fmt.Println("last defer")
}

//last defer
//defer in for [2]
//defer in for [1]
//defer in for [0]
//first defer
```

