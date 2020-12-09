---
title: "库源码文件和代码拆分"
date: 2020-12-08T13:12:08+08:00
toc: true
isCJKLanguage: true
tags: 
  - Go
---

## 什么是库源码文件

库源码文件是不能直接运行的源码文件，它仅提供程序实体以供其他代码使用。如：

```go
package lib5

import "fmt"

func Hello(name string) {
	fmt.Printf("Hello %s!\n", name)
}
```

把上面代码保存到 `libSource.go` 执行 `go run libSource.go` 得到：

```go
go run: cannot run non-main package
```

##  怎样把命令源码文件中的代码拆分到其他库源码文件？

首先来看代码：

```go
package main

import (
	"flag"
)

var name string

func init() {
	flag.StringVar(&name, "name", "Joseph", "The greeting object.")
}

func main() {
	flag.Parse()
	hello(name)
}
```

这里 `main` 没有直接输出，而是调用了 `hello()` 函数，函数声明在另一个源码文件中，我们把他命名为 `libSource.go` 并且把他放在和 `main.go` 相同的目录下：

```go
package main

import "fmt"

func hello(name string)  {
	fmt.Printf("Hello %s!\n", name)
}
```

执行命令 `go run main.go libSource.go`，得到结果：

```go
Hello Joseph!
```

注意，`main.go` 和 `libSource.go` 都声明自己属于 `main` 包，这是因为同一个目录下的源码文件必须要被声明为同一代码包，否则会报错：

```go
found packages main (main.go) and main1 (libSource.go) in /***/gowork/src/gocore/libSource
```

这句话是说在目录下找到了两个包。

另外也要注意源码文件声明的包名和所在的目录可以不相同，只要这些文件声明的包名一致就可以。

## 怎么把命令源码文件拆分到其他代码包

在 `main.go` 目录下新建目录 `lib` 并且创建文件 `libSource.go` 代码如下：

```go
package lib5

import "fmt"

func Hello(name string) {
	fmt.Printf("Hello %s!\n", name)
}
```

目前结构如下：

```go
.
├── go.mod
├── lib
│   └── libSource.go
├── libSource.go
└── main.go
```

这里和外面的 `libSource.go` 对比改了两个地方，一个是包名改了，并且和目录名不同，一个是 `Hello` 函数首字母改成了大写。

## 代码包的导入路径和其所在的目录的相对路径是否一致

库文件源码 `libSource.go` 所在目录的相对目录是 `lib` 但它却声明自己属于 `lib5` 包，那么该包的导入路径是 `libsource/lib` 呢还是 `libsource/lib5` 呢？`libsource` 是我的 `main.go` 所在目录。

我们来安装下库源码文件，执行命令 `go install lib/libSource.go` 然后看 `main.go` 做了哪些改动：

```go
package main

import (
	"flag"
	"libsource/lib"
)

var name string

func init() {
	flag.StringVar(&name, "name", "Joseph", "The greeting object.")
}

func main() {
	flag.Parse()
	//hello(name)
	lib5.Hello(name)
}
```

首先在以 `import` 为前导的代码包导入语句中加入 `libsource/lib` 试图导入代码包。

然后把对 `hello` 函数的调用改为对 `lib.Hello` 函数的调用。其中的 `lib.` 叫做限定符，旨在指明右边的程序实体所在的代码包。不过这里与代码包导入路径的完整写法不同，只包含了路径中的最后一级 `lib`，这与代码包声明语句中的规则一致。

执行 `go run main.go` 错误提示如下：

```go
./main.go:5:2: imported and not used: "libsource/lib" as lib5
./main.go:17:2: undefined: lib
```

第一行是说我们导入了 `libsource/lib` 但没有使用，`Go` 语言是不允许的，会报编译错误。

第二行是说没找到 `lib` 包。另外注意第一行的 `as lib5` 这是说我们虽然导入的是 `libsource/lib` 但是使用的应该是 `lib5`。

这里要记住源码文件所在的目录是相对于 `src` 目录的相对路径就是他的导入路径，而实际使用的是源码文件声明的所属包名。

为了不产生困惑，我们应该尽量保持包名与父目录名称一致。

## 什么样的程序才能够被外部代码引用

名称的首字母为大写的程序实体才可以被当前包外的代码引用，否则它就只能被当前包内的其他代码引用。

通过名称，`Go` 语言自然地把程序实体的访问权限划分为了包级私有的和公开的。对于包级私有的程序实体，即使你导入了它所在的代码包也无法引用到它。

这也是我们上面代码中把 `hello` 改为 `lib5.Hello` 的原因。

## 其他的访问权限规则

在 `Go 1.5` 及后续版本中，我们可以通过创建 `internal` 代码包让一些程序实体仅仅能被当前模块中的其他代码引用。这被称为 `Go` 程序实体的第三种访问权限：模块级私有。

具体规则是，`internal` 代码包中声明的公开程序实体仅能被该代码包的直接父包及其子包中的代码引用。当然，引用前需要先导入这个  `internal` 包。对于其他代码包，导入该 `internal` 包都是非法的，无法通过编译。

当前结构：

```go
.
├── go.mod
├── lib
│   ├── internal
│   │   └── internal.go
│   └── libSource.go
├── libSource.go
└── main.go
```

我们把 `lib/libSource.go` 中的 `Hello` 函数拆分到 `lib/internal/internal.go` 实现：

```go
package internal

import "fmt"

func Hello(name string)  {
	fmt.Printf("Hello %s!\n", name)
}
```

`lib/libSource.go`：

```go
package lib5

import "libsource/lib/internal"

func Hello(name string) {
	//fmt.Printf("Hello %s!\n", name)
	internal.Hello(name)
}
```

`main.go`：

```go
package main

import (
	"flag"
	"libsource/lib"
	"libsource/lib/internal"
)

var name string

func init() {
	flag.StringVar(&name, "name", "Joseph", "The greeting object.")
}

func main() {
	flag.Parse()
	//hello(name)
	lib5.Hello(name)
}
```

我们在 `main.go` 引入了  `internal` 包，执行 `go run main.go`：

```go
package command-line-arguments
        main.go:6:2: use of internal package libsource/lib/internal not allowed
```

可见是不被允许的，把 `libsource/lib/internal` 注释掉在执行：

```go
Hello Joseph!
```