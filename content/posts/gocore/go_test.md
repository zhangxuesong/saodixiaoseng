---
title: "测试的基本规则和流程"
date: 2020-12-22T09:50:10+08:00
toc: true
isCJKLanguage: true
tags: 
  - Go
---

## `Go` 程序测试基础知识

单元测试，又称程序员测试。顾名思义，就是程序员们本该做的自我检查工作之一。

`Go` 语言的缔造者们从一开始就非常重视程序测试，并且为 `Go` 程序的开发者们提供了丰富的 `API` 和工具。利用这些 `API` 和工具，我们可以创建测试源码文件，并且为命令源码文件和库源码文件中的程序实体编写测试用例。

在 `Go` 语言中，一个测试用例往往会由一个或多个测试函数来代表，大多情况下每个测试用例仅用一个测试函数就足够了。测试函数往往用于描述和保障某个程序实体的某方面功能，比如，该功能在什么情况下会因什么样的输入，产生什么样的输出，又比如，该功能会在什么情况下报错或表现异常等等。

我们可以为 `Go` 程序编写三类测试，即：功能测试（test）、基准测试（benchmark，也称性能测试）以及示例测试（example）。对于前两类测试，从名称上就应该可以猜到它们的用途，而示例测试严格来讲也是一种功能测试，只不过它更关注程序打印出来的内容。

一般情况下，一个测试源码文件只会针对于某个命令源码文件，或库源码文件做测试，所以我们总会（并且应该）把它们放在同一个代码包内。测试源码文件的名称应该以被测试源码文件的主名称为前导，并且必须以 `_test` 为后缀。比如，如果被测源码文件的名称为 `demo.go`，那么针对它的测试源码文件的名称就应该是 `demo_test.go`。

每个测试源码文件都必须至少包含一个测试函数。并且，从语法上来讲，每个测试源码文件中，都可以包含用来做任何一类测试的测试函数，即使把这三类测试函数都塞进去也没有问题。只要把控好测试函数的分组和数量就可以了。

我们可以根据这些测试函数针对的不同程序实体，把它们分成不同的逻辑组，并且利用注释以及帮助类的变量或函数来做分割。同时，我们还可以根据被测试源码文件中程序实体的先后顺序，来安排测试源码文件中测试函数的顺序。

## `Go` 语言对测试函数的名称和签名的规定

- 对于测试功能函数来说，其名称必须以 `Test` 为前缀，并且参数列表中只应有一个 `*testing.T` 类型的参数声明。
- 对于性能测试函数来说，其名称必须以 `Benchmark` 为前缀，并且唯一参数的类型必须是 `*testing.B` 类型的。
- 对于示例测试函数来说，其名称必须以 `Example` 为前缀，但对函数的参数列表没有强制规定。

只有测试源码文件的名称对了，测试函数的名称和签名也对了，当我们运行 `go test` 命令的时候，其中的测试代码才有可能被运行。

### `go test` 执行的测试流程

`go test` 命令在开始运行的时候，会先做一些准备工作。比如，确定内部需要用到的命令，检查我们指定的代码包或源码文件的有效性，以及判断我们给予的标记是否合法等等。

准备工作完成后，`go test` 命令就会针对每个被测试代码包，依次进行构建、执行包中符合要求的测试函数，清理临时文件，打印测试结果。这就是通常情况下的主要测试流程。

对于每个代码包，`go test` 命令会串行的执行测试流程中的每个步骤。但是，为了加快速度，它通常会并发的对多个被测代码包进行功能测试。只是在最后打印测试结果时会依照我们给定的顺序逐个进行，这会让我们感觉到它是完全串行的执行测试流程。

另一方面，由于并发的测试会让性能测试的结果存在偏差，所以性能测试一般都是串行进行的。更具体的说，只有在所有的构建步骤都做完之后，`go test` 命令才会真正的开始进行性能测试。

并且，下一个代码包性能测试的进行，总会等到上一个代码包性能测试的结果打印完成才会开始，而且性能测试函数的执行也都会是串行化的。

