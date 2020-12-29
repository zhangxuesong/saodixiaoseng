---
title: "Go 语言错误处理 2"
date: 2020-12-18T15:24:34+08:00
toc: true
isCJKLanguage: true
tags: 
  - Go
---

## 怎么根据实际情况给出恰当的错误值

构建错误值体系的基本方式有两种，即：创建立体的错误类型体系和创建扁平的错误值列表。

### 错误类型体系

由于在 `Go` 语言中实现接口是非侵入式的，所以可以做的很灵活。比如，在标准库 `net` 代码包中有一个名为 `Error` 的接口类型。它算是内建接口类型 `error` 的一个扩展接口，因为 `error` 是 `net.Error` 的嵌入接口。

```go
// An Error represents a network error.
type Error interface {
	error
	Timeout() bool   // Is the error a timeout?
	Temporary() bool // Is the error temporary?
}
```

`net.Error` 接口除了拥有 `error` 接口的 `Error` 方法之外，还有两个自己声明的方法：`Timeout` 和 `Temporary`。

`net` 包中很多错误类型都实现了 `net.Error` 接口，如：

1. `*net.OpError`
2. `*net.AddrError`
3. `net.UnKnownNetworkError` 等

我们可以把这些错误类型想象成一棵树，内建函数 `error` 就是树的根，而 `net.Error` 就是树一个在根上延伸的第一级非叶子节点。

同时，也可以把这看作是一种多层分类的手段。当 `net` 包的使用者拿到一个错误值的时候，可以判断它是否是 `net.Error` 类型的，也就是说该值是否代表了一个网络相关的错误。如果是，还可以再进一步判断它的类型是哪一个更具体的错误类型，这样就能知道这个网络相关的错误是由于操作不当引起的，还是因为网络地址错误引起的，又或是由于网络协议不正确引起的。

当我们细看 `net` 包中的这些具体错误类型的实现时，还会发现与 `os` 包中的一些错误类型相似，它们也都有一个名为 `Err` 类型为 `error` 接口类型的字段，代表也是当前错误的潜在错误。

所以说，这些错误值之间还可以有另一种关系，链式关系。比如，使用者调用 `net.DialTCP` 之类的函数时，`net` 包中的代码可能返回一个 `*net.OpError` 类型的错误值，以表示由于他的操作不当造成了一个错误。同时，这些代码还可能把一个 `*net.AddrError` 或 `net.UnKnownNetworkError` 类型的值赋给该错误值的 `Err` 字段，以表明导致这个错误的潜在原因。如此，这里的潜在错误值的 `Err` 字段也有非 `nil` 的值，那么将会指向更深层次的错误原因。这样一级又一级就像链条一样最终指向问题的根源。

以上这些内容总结成一句话就是，用类型建立起树形结果的错误体系，用统一字段建立起可追根溯源的链式错误关联。这是 `Go` 语言标准库给与我们的优秀范本，非常有借鉴意义。

注意，如果不希望包外代码改动返回的错误值的话，一定要小写其中字段名称首字母。我们可以通过暴露某些方法让包外代码有进一步获取错误信息的权限，比如编写一个可以返回一个包级私有的 `err` 字段值的公开方法 `Err`。

### 错误值列表

当我们只想预先创建一些代表已知错误的错误值时，用这种扁平化的方式就很恰当了。不过，由于 `error` 是接口类型，所以通过 `errors.New` 函数生成的错误值只能赋给变量，而不能赋给常量，又由于这些代表错误的变量需要给包外代码使用，所以其访问权限只能是公开的。

这就带来一个问题，如果有恶意代码修改了这些公开变量的值，那么程序就必然会受到影响。因为这种情况下我们往往会通过判等操作来判断拿到的错误值具体是哪一个错误，如果这些公开变量的值被改变了，那么相应的判等操作也会随之改变。

这里有两个解决方案：

#### 第一个方案

先私有化此类变量。也就是说，让它们名称首字母变成小写，然后编写公开的用于获取错误值以及用于判等错误值的函数。

比如，对于错误值 `os.ErrClosed`，先改写它的名称，让其变成 `os.errClosed`，然后再编写 `ErrClosed` 函数和 `IsErrClosed` 函数。

当然了，这不是说让我们去改动标准库中已有的代码，这样做的危害会很大，甚至是致命的。只能说，对于我们可控的代码，最好还是要尽量收紧访问权限。

#### 第二个方案

此方案存在于 `syscall` 包中。该包中有一个类型叫做 `Errno`，该类型代表了系统调用时可能发生的底层错误。这个错误类型是 `error` 接口的实现类型，同时也是对内建类型 `uintptr` 的在定义类型。

由于 `uintptr` 可以作为常量的类型，所以 `syscall.Errno` 自然也可以。`syscall` 包中声明有大量的 `Errno` 类型的常量，每个常量对应一种系统调用错误。`syscall` 包外的代码可以拿到这些代表错误的常量，但无法改变它们。

我们可以仿照这种声明方式来构建我们自己的错误值列表，这样就可以保证错误值的只读特性了。