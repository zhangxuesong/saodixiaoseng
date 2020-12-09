---
title: "命令源码文件和 flag 库"
date: 2020-12-07T14:05:35+08:00
toc: true
isCJKLanguage: true
tags: 
  - Go
---

## 前言

写了N年代码，只知道源码文件，原来细分的话源码文件也有区分，如：

- 命令源码文件
- 库源码文件
- 测试源码文件

他们也有不同的用途和规则。

## 命令源码文件

命令源码文件是程序的运行入口，是每个可独立运行的程序必须拥有的。通过执行构建和安装，生成其对应的可执行文件，可执行文件一般与命令源码文件的父级目录同名。

如果一个源码文件声明属于`main`包，并且包含一个无参数声明并且无结果声明的`main`函数，那面它就是命令源码文件，如：

```go
package main

import "fmt"

func main()  {
	fmt.Println("hello go!!")
}
```

把这段代码保存到 `main.go` 文件，执行 `go run main.go` 就会输出 `hello go!!`

> 通常模块化编程时，我们会把代码拆分到多个文件，甚至拆分到不同的代码包中。但不管怎样，对于一个独立的程序来说，命令源码文件永远也只会有一个。如果有与命令源码文件同包的源码文件，那么它们也应该声明属于main包。

通过构建或安装命令源码文件可以生成可执行文件，这里的可执行文件就可以视为“命令”，既然是命令，那面就应该具备接受参数的能力。

### 命令源码文件怎样接收参数

接收参数我们需要用到 `flag` 包 ，它是 `Go` 语言标准库提供的专门解析命令行参数的代码包。具体怎么使用呢，我们来看代码：

```go
package main

import (
	"flag"
	"fmt"
)

var name string

func init() {
	flag.StringVar(&name, "name", "Joseph", "The greeting object.")
}

func main()  {
	flag.Parse()
	fmt.Printf("hello %s!\n", name)
}
```

上面代码中，我们用 `flag.StringVar()` 函数，该函数接收 4 个参数：

- 第一个参数是用于存储命令参数值的地址，我们这里就是前面声明的 `name` 变量的地址了，这里用 `&name` 表示。
- 第二个参数是指定该命令接收的参数名称，这里是 `name` 。
- 第三个参数是指定了未输入该命令参数时的默认值，这里是 `Joseph`。
- 第四个参数是该命令参数的简短说明，`--help` 时会用到。

另外这里还有个相似的函数 `flag.String()` 区别是前者把接收到的命令参数值绑定到了指定的变量，后者直接返回了命令参数值的指针。

```go
flag.String("name", "Joseph", "The greeting object.")
```

参数列表少了第一个。

函数  `flag.Parse()` 用于真正解析命令参数，并把它们赋值给相应变量。对该函数的调用必须在所有命令参数存储载体声明（变量 `name` 声明）和设置（对 `flag.StringVal()` 调用）之后，并且在读取任何命令参数值之前进行。所以，我们最好把它放在 `main` 函数体的第一行。

### 怎样在运行命令源码文件的时候传入参数，怎样查看参数说明

把上面代码保存到 `main.go` 文件，运行下面命令就可以为参数 `name` 传值：

```go
go run main.go -name="golang"
```

运行后，输出结果：

```go
hello golang!
```

查看参数说明可以执行下面命令：

```go
go run main.go --help
```

运行后结果类似：

```go
Usage of /var/folders/nt/vczl6v_963vb3pr63m_v12kh0000gn/T/go-build422118775/b001/exe/main:
  -name string
        The greeting object. (default "Joseph")
```

其中：

```go
/var/folders/nt/vczl6v_963vb3pr63m_v12kh0000gn/T/go-build422118775/b001/exe/main
```

是 `go run` 命令构建源码文件所产生的临时可执行文件存储路径。

如果先构建源码文件在执行，像这样：

```go
go build main.go
./main --help
```

那面输出就是：

```go
Usage of ./main:
  -name string
        The greeting object. (default "Joseph")
```

### 怎样自定义命令源码文件的参数使用说明

#### 1、对变量 `flag.Usage` 重新赋值

`flag.Usage` 的类型是 `func()`，是一种无参数声明且无返回结果声明的函数类型。其在声明的时候就已经被赋值了，所以运行命令 `--help` 时才能看到结果。

我们对 `flag.Usage` 进行赋值必须在 `flag.Parse` 之前，如：

```go
func main()  {
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "%s使用说明:\n", "参数")
		flag.PrintDefaults()
	}
	flag.Parse()
	fmt.Printf("hello %s!\n", name)
}
```

执行 `--help` 命令得到：

```go
参数使用说明:
  -name string
        The greeting object. (default "Joseph")
```

#### 2、对变量 `flag.CommandLine` 重新赋值

我们在调用 `flag` 包中的一些函数如：`StringVal`、`Parse` 时实际在调用 `flag.CommandLine` 变量的对应方法。

`flag.CommandLine` 相当于默认的命令参数容器，通过对其重新赋值，可以更深层次的定制当前命令源码文件的参数说明。

```go
package main

import (
	"flag"
	"fmt"
	"os"
)

//var name = flag.String("name", "Joseph", "The greeting object.")
var name string

func init() {
	flag.CommandLine = flag.NewFlagSet("", flag.ExitOnError)
	flag.CommandLine.Usage = func() {
		fmt.Fprintf(os.Stderr, "%s使用说明:\n", "参数")
		flag.PrintDefaults()
	}

	flag.StringVar(&name, "name", "Joseph", "The greeting object.")
}

func main()  {
	//flag.Usage = func() {
	//	fmt.Fprintf(os.Stderr, "%s使用说明:\n", "参数")
	//	flag.PrintDefaults()
	//}
	flag.Parse()
	fmt.Printf("hello %s!\n", name)
}
```

`flag.NewFlagSet()` 的第二个参数可以设置使用 `--help` 时的响应状态，比如：

- 设为 `flag.ContinueOnError` 时得到结果：

```go
参数使用说明:
  -name string
        The greeting object. (default "Joseph")
hello Joseph!
```

- 设为 `flag.ExitOnError` 时得到结果：

```go
参数使用说明:
  -name string
        The greeting object. (default "Joseph")
```

- 设为 `flag.PanicOnError` 时得到结果：

```go
参数使用说明:
  -name string
        The greeting object. (default "Joseph")
panic: flag: help requested

goroutine 1 [running]:
flag.(*FlagSet).Parse(0xc0000561e0, 0xc00000c090, 0x1, 0x1, 0xc000068f78, 0x1005a65)
        /usr/local/Cellar/go/1.15.5/libexec/src/flag/flag.go:987 +0x145
flag.Parse(...)
        /usr/local/Cellar/go/1.15.5/libexec/src/flag/flag.go:1002
main.main()
        /Users/zhangxuesong/gowork/src/gocore/commandSource/main.go:27 +0x85
exit status 2
```

#### 3、创建私有命令参数容器

```go
package main

import (
	"flag"
	"fmt"
	"os"
)

//var name = flag.String("name", "Joseph", "The greeting object.")
var name string
var cmdLine = flag.NewFlagSet("参数", flag.ExitOnError)

func init() {
	//flag.CommandLine = flag.NewFlagSet("", flag.ExitOnError)
	//flag.CommandLine.Usage = func() {
	//	fmt.Fprintf(os.Stderr, "%s使用说明:\n", "参数")
	//	flag.PrintDefaults()
	//}

	//flag.StringVar(&name, "name", "Joseph", "The greeting object.")

	cmdLine.StringVar(&name, "name", "Joseph", "The greeting object.")
}

func main()  {
	//flag.Usage = func() {
	//	fmt.Fprintf(os.Stderr, "%s使用说明:\n", "参数")
	//	flag.PrintDefaults()
	//}
	//flag.Parse()

	cmdLine.Parse(os.Args[1:])
	fmt.Printf("hello %s!\n", name)
}

```

需要注意的是 `os.Args[1:]` 表示解析参数从第二个开始，第一个是文件名。

