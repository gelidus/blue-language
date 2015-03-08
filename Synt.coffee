Lex = require("./Lex")

module.exports = class Synt

  constructor: (file) ->
    @lex = new Lex(file)

  generateTree: () ->
    tree = {
      imports: []
      entities: []
    }

    loop
      # parse next entity
      entity = @parseEntity()
      break if not entity?

      switch entity.nodeType
        when "function" then tree.entities.push(entity)
        when "import" then tree.imports.push(entity)

    return tree

  parseEntity: () ->
    first = @lex.markToken(true)

    return null if not first?

    if first.type is "keyword" and first.value is "import"
      return @parseImportStatement()
    else if first.type is "type"
      return @parseFunctionStatement()

  parseFunctionParameters: (func) ->
    leftBracket = @lex.getToken()

    parameters = []
    loop
      type = @lex.markToken()
      break if type.value is ")" # break on right bracket
      @lex.getToken() # remove type token from front

      name = @lex.getToken()

      # create parameter object
      parameters.push({
        nodeType: "funcparam"
        type: type.value
        name: name.value
      })

      comma = @lex.markToken()
      break if comma.value is ")"
      @lex.getToken() # remote comma from front

    rightBracket = @lex.getToken()

    return parameters

  parseBody: (baseIndent) ->
    body = []

    loop
      any = @lex.markToken(true)
      break if any is null or not any.line.indent > baseIndent

      if any.type is "type"
        body.push(@parseDeclarationStatement())
      else if any.type is "variable" and @lex.markToken()? and @lex.markToken().value is "="
        body.push(@parseAssignStatement())
      else if any.type is "keyword" and any.value is "return"
        body.push(@parseReturnStatemnt())
      else
        body.push(@parseExpressionStatement())

    return body

  ###  Statements  ###

  parseImportStatement: () ->
    include = @lex.getToken() # import token
    name = @lex.getToken()

    include = {
      nodeType: "import"
      name: name.value
    }

    option = @lex.markToken(true)
    if option.type is "misc" and option.value is ":"
      option = @lex.getToken()
      include.option = "unpacked" # import all to current namespace "std:print"
    else
      include.option = "packed" # import all and stay in package "print"

    return include

  parseFunctionStatement: () ->
    returnType = @lex.getToken()

    return if returnType is null

    functionName = @lex.getToken()

    func = {
      nodeType: "function"
      name: functionName.value
      returnType: returnType.value
      indent: returnType.line.indent
    }

    func.parameters = @parseFunctionParameters(func)

    # -> operator
    arrow = @lex.getToken()

    # parse whole body
    func.body = @parseBody(func.indent)

    return func

  ###
    (variable) = (expression)
  ###
  parseAssignStatement: () ->

  ###
    (type) (variable) [= (expression)]
  ###
  parseDeclarationStatement: () ->
    type = @lex.getToken()
    name = @lex.getToken()

    vardecl = {
      nodeType: "vardecl"
      type: type.value
      name: name.value
      expression: []
    }

    assign = @lex.markToken()
    if assign.type is "operator" and assign.value is "="
      @lex.getToken() # retrieve marked token
      vardecl.expression = @parseExpressionStatement()

    return vardecl

  ###
    (expression)
  ###
  parseExpressionStatement: () ->
    expression = {
      nodeType: "expression"
      body: []
    }
    expressionLine = null

    state = "variable"
    loop
      token = @lex.markToken(true)

      break if token is null or (expressionLine? and token.line.number isnt expressionLine)

      if state is "variable" and (token.type not in ["variable", "number", "string"])
        break

      if state is "operator" and (token.type not in ["operator", "bracket", "misc"])
        break;

      expressionLine = expressionLine || token.line.number
      token = @lex.getToken() # retrieve from marked tokens

      expression.body.push({
        nodeType: "exprnode"
        type: token.type
        value: token.value
      })

      state = if state is "variable" then "operator" else "variable"

    return expression

  ###
    return (expression)
  ###
  parseReturnStatemnt: () ->
    ret = @lex.getToken()

    expr = @parseExpressionStatement()

    return {
      nodeType: "return"
      expression: expr
    }

  ###              ###