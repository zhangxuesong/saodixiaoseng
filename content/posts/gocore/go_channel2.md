---
title: "通道的高级玩法"
date: 2020-12-14T15:14:51+08:00
toc: true
isCJKLanguage: true
tags: 
  - Go
---

## 单向通道

我们通常说通道都是指双向通道，即：即可以发也可以收的通道。

所谓单向通道就是 只能发不能收 或者 只能收不能发 的通道。一个通道是单向还是双向的由它的字面量体现。

接收操作符 `<-` 如果用在通道的类型字面量中，它代表的就不再是接收或者发送的动作了，而是通道的方向。

```go
make(chan<- int)//发送通道，只能发不能收
make(<-chan int)//接收通道，只能收不能发
```

### 单向通道的应用价值

概括的说，单向通道最主要的用途就是约束其他代码的行为。

```go
func SendInt(ch chan<- int) {
	ch <- rand.Intn(1000)
	//fmt.Printf("element of channel: %v.\n", <- ch)
}
```

上面这段代码声明了一个函数，只接受一个发送通道，那么函数中就只能像通道发送元素值而不能从通道接收元素值。这就起到了约束函数行为的作用。

如果是接口类型中声明的某个函数的定义使用了单向通道，那么等于该接口类型的所有实现都受到了约束。

我们在调用的这个函数的时候，只需要把一个元素类型匹配的双向通道传给它，`Go` 会自动把通道转成函数需要的单向通道。

```go
ch3 := make(chan int, 1)
SendInt(ch3)
elmt3, ok := <- ch3
fmt.Printf("elemt3 is %v. channel stats is %v.\n", elmt3, ok)

//elemt3 is 81. channel stats is true.
```

我们还可以在函数声明的结果列表中使用单向通道，如：

```go
func getIntChan() <-chan int {
	num := 5
	ch := make(chan int, num)
	for i := 0; i < num; i++ {
		ch <- i
	}
	close(ch)
	return ch
}
```

函数返回一个接收通道，这以为这得到该通道的程序只能从通道中读取数据。这实际上也是对函数调用方的一种约束。

`Go` 语言中还可以声明函数类型，如果在函数类型中使用了单向通道，那么等于约束了所有实现了这个函数类型的函数。

看下函数调用结果：

```go
ch4 := getIntChan()
for elemt := range ch4 {
    fmt.Printf("the element in ch4: %v.\n", elemt)
}
```

`for` 语句会不断的尝试从通道 `ch4` 中读取元素值。即使通道被关闭了，它也会取出所有剩余元素值后再结束运行。

通常通道里没有元素值时，`for` 语句会阻塞在这里直到有新的元素值可取。但这里因为函数里把通道关闭了，所以取出通道内的所有元素值后会结束运行。

如果通道的值为 `nil`，那么 `for` 语句就永远阻塞在这里。

## `select` 和通道是怎样连用

`select` 和 `switch` 用法差不多，但是只能和通道联用，每个 `case` 都只能包含通道表达式。

```go
// 准备好几个通道。
intChannels := [3]chan int{
    make(chan int, 1),
    make(chan int, 1),
    make(chan int, 1),
}
// 随机选择一个通道，并向它发送元素值。
index := rand.Intn(3)
fmt.Printf("The index: %d\n", index)
intChannels[index] <- index
// 哪一个通道中有可取的元素值，哪个对应的分支就会被执行。
select {
    case <-intChannels[0]:
    fmt.Println("The first candidate case is selected.")
    case <-intChannels[1]:
    fmt.Println("The second candidate case is selected.")
    case elem := <-intChannels[2]:
    fmt.Printf("The third candidate case is selected, the element is %d.\n", elem)
    default:
    fmt.Println("No candidate case is selected!")
}
```

首先声明了一个 3 个元素的通道数组，每个元素都是 `int` 类型，容量为 1 的双向通道。然后随机生成一个范围在 0,2 的整数，把它作为索引从上面的数组中选择一个通道并像其中发送一个元素值。最后用 `select` 分别尝试从数组中的 3 个通道中接收元素值，哪一个通道有值，则执行对应的分支。如果都没有的话则执行默认分支。

使用 `select` 时，应注意以下几点：

- 如果使用了默认分支，那么无论涉及通道的操作是否阻塞，`select` 语句都不会阻塞。因为如果没有满足求职条件的话，就会执行默认分支。
- 如果没有使用默认分支，那么当所有 `case` 分支都不满足求职条件的话，`select` 语句就会被阻塞，直到有一个 `case` 表达式满足条件。
- 我们需要通过第二个结果值来判断通道是否已经关闭，如果关闭了，就应该及时屏蔽掉对应分支或者采取其他措施。这对于程序逻辑和程序性能是有好处的。
- `select` 语句只能对其中的每一个 `case` 表达式各求值一次，如果想连续或定时操作其中的通道的话，通常需要通过 `for` 语句中嵌套 `select` 的方式实现。这时需要注意，在 `select` 中使用 `break` 只能结束当前的 `select` 语句执行，并不会对外层的 `for` 产生作用。

```go
intChan := make(chan int, 1)
// 一秒后关闭通道。
time.AfterFunc(time.Second, func() {
  close(intChan)
})
select {
case _, ok := <-intChan:
  if !ok {
    fmt.Println("The candidate case is closed.")
    break
  }
  fmt.Println("The candidate case is selected.")
}
```

## `select` 语句的分支选择规则

+ 对于每一个 `case` 表达式，都至少会包含一个代表发送或者接受的表达式。同时也可能包含其他表达式。
+ `select` 语句包含的候选分支中的 `case` 表达式都会在该语句执行开始时先被求值。并且求值顺序是从上到下的。
+ 对每一个 `case` 表达式求值时，如果相应的操作正处于阻塞状态，那么这个 `case` 表达式所在的候选分支是不满足条件的。
+ 一个候选分支中的所有 `case` 表达式都被求值完毕后，才会继续下一个候选分支。当所有候选分支都不满足条件时，会执行默认分支。如果没有默认分支，`select` 会阻塞，直到有满足条件的候选分支。
+ 如果有多个候选分支满足条件，`select` 会用一种伪随机的算法在其中选择一个执行。
+ 一条 `select` 语句只能有一个默认分支，并且默认分支只能在无候选分支可选时才会被执行。
+ `select` 语句的每次执行，包括 `case` 表达式求值和分支选择，都是独立的。至于它们执行是否是并发安全的，需要看其中是否有包含并发不安全的代码。