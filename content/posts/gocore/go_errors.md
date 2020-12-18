---
title: "Go 语言错误处理"
date: 2020-12-18T14:12:32+08:00
toc: true
isCJKLanguage: true
tags: 
  - Go
---

`error` 类型是一个接口类型，也是一个 `Go` 语言的内建类型。在这个接口类型的声明中只包含了一个方法 `Error`。它不接受任何参数，但是返回一个 `string` 类型的结果。它的作用是返回错误信息的字符串表示形式。

使用 `error` 类型的方式通常是，在函数声明的结果列表最后，声明一个该类型的结果，同时在调用这个函数之后，先判断它返回的最好一个结果值是否不为 `nil`。如果这个值不为 `nil`，那么进入错误处理流程，否则就继续进行正常流程。

```go
package main

import (
	"errors"
	"fmt"
)

func echo(request string) (response string, err error) {
	if request == "" {
		err = errors.New("empty request")
		return
	}
	response = fmt.Sprintf("echo: %s", request)
	return
}

func main() {
	for _, req := range []string{"", "hello"} {
		fmt.Printf("request: %s\n", req)
		resp, err := echo(req)
		if err != nil {
			fmt.Printf("error: %s\n", err.Error())
			continue
		}
		fmt.Println(resp)
	}
}
```

在 `echo` 函数和 `main` 函数中都是用了卫述语句，它是被用来检查后续操作的前置条件并进行相应处理的语句。对于 `echo` 函数来说，传入的参数值一定要符合要求。而对于调用它的程序来说，进行后续操作的前提就是 `echo` 函数的执行不能出错。

生成 `error` 类型值的时候用到了 `errors.New` 函数，这是一种最基本的生成错误值的方式。调用它的时候传入一个由字符串代表的错误信息，它会返回一个包含了这个错误信息的 `error` 类型值。该值的静态类型当然是 `error`，而动态类型则是一个在 `errors` 包中的包级私有类型 `*errorString`。

```go
// because the former will succeed if err wraps an *os.PathError.
package errors

// New returns an error that formats as the given text.
// Each call to New returns a distinct error value even if the text is identical.
func New(text string) error {
	return &errorString{text}
}

// errorString is a trivial implementation of error.
type errorString struct {
	s string
}

func (e *errorString) Error() string {
	return e.s
}
```

显然，`errorString` 类型拥有的一个指针方法实现了 `error` 接口中的 `Error` 方法。这个方法被调用后，会原封不动的返回我们之前传入的错误信息。实际上，`error` 类型值的 `Error` 方法就相当于其他类型的 `String` 方法。

我们知道，通过 `fmt.Printf` 函数给定占位符 `%s` 就可以打印出某个值的字符串表示形式，对于其他类型来说，只有为这个类型编写了 `String` 方法，就可以自定义它的字符串表示形式。而对于 `error` 类型值，它的字符串表示形式则取决于它的 `Error` 方法。

在上述情况下，`fmt.Printf` 函数如果发现一个被打印的值是一个 `error` 类型的值，那么会去调用它的 `Error` 方法。`fmt` 包中的这类打印函数其实都是这么做的。

当需要通过模板化的方式生成错误信息并得到错误值时，可以使用 `fmt.Errorf` 函数。该函数所做的其实就是先调用 `fmt.Sprintf` 函数，得到确切的错误信息，再调用 `errors.New` 函数，得到包含该错误信息的 `error` 类型值，最后返回该值。

## 怎么判断一个错误值代表的哪类错误

- 对于类型在已知范围内的一系列错误值，一般使用类型断言表达式或类型 `switch` 语句来判断。
- 对于已有相应变量且类型相同的一系列错误值，一般直接使用判等操作来判断。
- 对于没有相应变量且类型未知的一系列错误值，只能使用错误信息的字符串表示形式来判断。

### 类型在已知范围内的错误值

拿 `os` 包中的几个代表错误的类型 `os.PathError`、`os.LinkError`、`os.SyscallError` 和 `os/exec.Error` 来说，它们的指针类型都是 `error` 接口的实现类型，同时它们也都包含了一个名叫 `Err`，类型为 `error` 接口类型的代表潜在错误的字段。

如果我们得到一个 `error` 类型值，并且知道该值的实际类型肯定是它们中的一个，那么就可以用 `switch` 语句去判断：

```go
func underlyingError(err error) error {
	switch err := err.(type) {
	case *os.PathError:
		return err.Err
	case *os.LinkError:
		return err.Err
	case *os.SyscallError:
		return err.Err
	case *exec.Error
		return err.Err
	}
	return err
}
```

函数 `underlyingError` 的作用是：获取和返回已知操作系统相关错误的潜在错误值。其中 `switch` 语句中若干个 `case` 子句分别对应了上述的几种错误类型，当它们被选中时，都会把参数 `err` 的 `Err` 字段作为结果值返回。如果它们都未被选中，那么该函数就把参数值当做结果返回，即放弃获取潜在错误值。

只要类型不同，我们就可以如此分辨。但在错误类型相同的情况下，这些手段就无能为力了。在 `Go` 语言标准库中也有不少以相同方式创建同类型的错误值。

还拿 `os` 包来说，其中不少错误值都是通过调用 `errors.New` 来初始化的，比如：`os.ErrClosed`、`os.ErrInvalid` 以及 `os.ErrPermission` 等。

注意，与前面的几个错误类型不同，这几个都是已经定义好的、确切的错误值。`os` 包中的代码有时候会把它们当做潜在错误值封装进前面那些错误类型值中。

如果我们在操作文件系统的时候得到了一个错误值，并且知道该值的潜在错误值肯定是上述值中的某一个，那么就可以用普通的 `switch` 语句去做判断，当然了，`if` 语句和判等操作符也是可以的：

```go
printError := func(i int, err error) {
    if err == nil {
        fmt.Println("nil error")
        return
    }
    err = underlyingError(err)
    switch err {
        case os.ErrClosed:
        fmt.Printf("error(closed)[%d]: %s\n", i, err)
        case os.ErrInvalid:
        fmt.Printf("error(invalid)[%d]: %s\n", i, err)
        case os.ErrPermission:
        fmt.Printf("error(permission)[%d]: %s\n", i, err)
    }
}
```

这个由 `printError` 变量代表的函数会接受一个 `error` 类型的参数值。该值总会代表某个文件操作相关的错误，这是我故意地以不正确的方式操作文件后得到的。

虽然我不知道这些错误值的类型的范围，但却知道它们或它们的潜在错误值一定是某个已经在 `os` 包中定义的值。

所以，我先用 `underlyingError` 函数得到它们的潜在错误值，当然也可能只得到原错误值而已。然后，我用 `switch` 语句对错误值进行判等操作，三个 `case` 子句分别对应我刚刚提到的那三个已存在于 `os` 包中的错误值。如此一来，我就能分辨出具体错误了。

对于上面这两种情况，我们都有明确的方式去解决。但是，如果我们对一个错误值可能代表的含义知之甚少，那么就只能通过它拥有的错误信息去做判断了。

好在我们总是能通过错误值的 `Error` 方法，拿到它的错误信息。其实 `os` 包中就有做这种判断的函数，比如：`os.IsExist`、`os.IsNotExist` 和 `os.IsPermission`。

```go
printError2 := func(i int, err error) {
    if err == nil {
        fmt.Println("nil error")
        return
    }
    err = underlyingError(err)
    if os.IsExist(err) {
        fmt.Printf("error(exist)[%d]: %s\n", i, err)
    } else if os.IsNotExist(err) {
        fmt.Printf("error(not exist)[%d]: %s\n", i, err)
    } else if os.IsPermission(err) {
        fmt.Printf("error(permission)[%d]: %s\n", i, err)
    } else {
        fmt.Printf("error(other)[%d]: %s\n", i, err)
    }
}
```

