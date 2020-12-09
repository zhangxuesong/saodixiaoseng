---
title: "Go 语言中的类型断言"
date: 2020-12-09T16:34:11+08:00
toc: true
isCJKLanguage: true
tags: 
  - Go
---

## 怎样判断一个变量的类型

先来看一段代码：

```go
package main

import "fmt"

var container = []string{"0", "1", "2"}

func main() {
	container := map[int]string{0: "0", 1: "1", 2: "2"}
	fmt.Printf("the element is %q.\n", container[1])
}
```

怎样在打印期中元素之前判断 `container` 的类型呢，当然是用类型断言：

```go
value, ok := interface{}(container).([]string)
```

这是一条赋值语句，赋值符号右边是类型断言表达式。它包括了用来把 `container` 变量转换为空接口值的 `interface{}(container)`，以及用于判断前者类型是否是切片类型 `[]string` 的 `.([]string)`。

表达式的结果被赋给两个变量，`ok` 代表类型判断的结果，`true` 或 `false`。

如果是 `true`，被判断的值将会自动转换成 `[]string` 的值赋给 `value` 否则会赋给 `nil`。

这里的 `ok` 也可以没有，当判断为否时会引发异常。

类型断言的语法表达形式：

```go
x.(T)
```

`x` 代表要被判断的值，这个值必须是接口类型。

所以前面 `container` 不是接口类型，要先转化一下。如果是接口类型那面可以这样表示：

```go
container.([]string)
```

![](./image/b5f16bf3ad8f416fb151aed8df47a515.png)

### 类型转换规则中的坑

首先，对于整数类型值、整数常量之间的类型转化，原则上只要源值在目标类型的可表示范围内就是合法的。

比如，之所以 `uint8(255)` 可以把无类型的常量 255 转换为 `uint8` 类型的值，是因为 255 在 [0, 255] 的范围内。

再比如，`int16(-255)` 转为 `int8` 类型会变成 1。

因为整数在 `Go` 语言中是以补码形式存储的，主要是为了简化计算机对整数的运算过程。负数补码就是源码各位求反再加一。

`int16` 类型的值 -255 的补码是 1111111100000001。如果我们把该值转换为 `int8` 类型的值，那么 `Go` 语言会把在较高位置（或者说最左边位置）上的 8 位二进制数直接截掉，从而得到 00000001。又由于其最左边一位是 0，表示它是个正整数，以及正整数的补码就等于其原码，所以最后的值就是 1。

注意，当整数值的类型范围由宽变窄时，只需要在补码形式下截掉以定长度的高位二进制。

第二，整数值转字符串时，被转换的整数值应该可以代表一个有效的 `Unicode` 代码点，否则结果会是 �。

字符 � 的 `Unicode` 代码点是 `U+FFFD`，它是 `Unicode` 标准中定义的 `Replacement Character`， 专门用来替换未知的、不被认可的一级无法展示的字符。

如 `string(-1)`，-1 肯定无法代表一个有效的 `Unicode` 代码点，所以得到的总是 �。

第三，字符串类型与各种切片类型之间的互转。

一个值从 `string` 类型向 `[]byte` 类型转换时代表着以 `UTF-8` 编码的字符串会被拆分成零散、独立的字节。

一个值从 `string` 类型向 `[]rune` 类型转换时代表着字符串会被拆分成一个个 `Unicode` 字符。

## 什么是类型别名，什么是潜在类型

`Go` 语言中可以使用 `type` 关键字声明自定义的各种类型。其中有一种 别名类型 的类型。我们可以这样声明：

```go
type MyString = string
```

这表明 `MyString` 是 `string` 类型的别名类型。别名类型和源类型只是名称不同，其他完全相同。

`Go` 语言内建的基本类型中就存在两个别名类型。`byte` 是 `uint8` 的别名类型，而 `rune` 是 `int32` 的别名类型。

注意，如果像这样声明：

```go
type MyString string
```

`MyString` 和 `string` 就是两个不同的类型了，这里的 `MyString` 是不同于任何类型的新类型。

这种方式也叫做类型的在定义，即：把 `string` 类型在定义为 `MyString` 类型。

![](./image/4f113b74b564ad3b4b4877abca7b6bf2.png)

对应类型再定义来说，`string` 可以被称为 `MyString` 的潜在类型，潜在类型的含义就是某个类型的本质上是什么类型。

潜在类型相同的不同类型的值之间是可以进行类型转换的。所以 `MyString` 类型的值与 `string` 类型的值可以使用类型转换表达式互转。

但由于类型再定义后属于不同的类型，不同类型直接不可以做判等或者比较，也不能直接赋值。