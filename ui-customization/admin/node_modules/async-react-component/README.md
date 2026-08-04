![npm-version](https://img.shields.io/npm/v/async-react-component.svg) ![license](https://img.shields.io/npm/l/async-react-component.svg) ![bower-license](https://img.shields.io/bower/l/async-react-component.svg)

# async-react-component

Async component loaded based webpack 3 for react-router 4.

## Install

It is recommended to run webpack on node 6.x or higher.

Install the pkg with npm:

```
npm install async-react-component --save
```

or yarn

```
yarn add async-react-component
```

or bower

```
bower install async-react-component
```

## Usage

For react-router 4:

```
import {BrowserRouter as Router, Route, Switch} from 'react-router-dom';
import {getAsyncComponent} from 'async-react-component';

// code splitting in webpack 3: https://webpack.js.org/guides/code-splitting/#dynamic-imports
const App = () => import(/* webpackChunkName: "main" */ '../general/app/index');
const Info = () => import(/* webpackChunkName: "info" */ '@components/info/index');

const RootApp = () => {
    return (
        <Router>
            <Switch>
                <Route exact path='/' component={getAsyncComponent(App)}></Route>
                <Route path='/info' component={getAsyncComponent(Info)}></Route>
                <Route render={() => <div>404 not found</div>}></Route>
            </Switch>
        </Router>
    );
};

ReactDOM.render(
    RootApp,
    document.getElementById('app')
);
```

## License
MIT