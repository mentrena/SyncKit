(window.webpackJsonp=window.webpackJsonp||[]).push([[26],{132:function(e,t,r){"use strict";r.d(t,"a",(function(){return p})),r.d(t,"b",(function(){return m}));var n=r(0),l=r.n(n);function a(e,t,r){return t in e?Object.defineProperty(e,t,{value:r,enumerable:!0,configurable:!0,writable:!0}):e[t]=r,e}function i(e,t){var r=Object.keys(e);if(Object.getOwnPropertySymbols){var n=Object.getOwnPropertySymbols(e);t&&(n=n.filter((function(t){return Object.getOwnPropertyDescriptor(e,t).enumerable}))),r.push.apply(r,n)}return r}function o(e){for(var t=1;t<arguments.length;t++){var r=null!=arguments[t]?arguments[t]:{};t%2?i(Object(r),!0).forEach((function(t){a(e,t,r[t])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(r)):i(Object(r)).forEach((function(t){Object.defineProperty(e,t,Object.getOwnPropertyDescriptor(r,t))}))}return e}function c(e,t){if(null==e)return{};var r,n,l=function(e,t){if(null==e)return{};var r,n,l={},a=Object.keys(e);for(n=0;n<a.length;n++)r=a[n],t.indexOf(r)>=0||(l[r]=e[r]);return l}(e,t);if(Object.getOwnPropertySymbols){var a=Object.getOwnPropertySymbols(e);for(n=0;n<a.length;n++)r=a[n],t.indexOf(r)>=0||Object.prototype.propertyIsEnumerable.call(e,r)&&(l[r]=e[r])}return l}var s=l.a.createContext({}),u=function(e){var t=l.a.useContext(s),r=t;return e&&(r="function"==typeof e?e(t):o(o({},t),e)),r},p=function(e){var t=u(e.components);return l.a.createElement(s.Provider,{value:t},e.children)},b={inlineCode:"code",wrapper:function(e){var t=e.children;return l.a.createElement(l.a.Fragment,{},t)}},d=l.a.forwardRef((function(e,t){var r=e.components,n=e.mdxType,a=e.originalType,i=e.parentName,s=c(e,["components","mdxType","originalType","parentName"]),p=u(r),d=n,m=p["".concat(i,".").concat(d)]||p[d]||b[d]||a;return r?l.a.createElement(m,o(o({ref:t},s),{},{components:r})):l.a.createElement(m,o({ref:t},s))}));function m(e,t){var r=arguments,n=t&&t.mdxType;if("string"==typeof e||n){var a=r.length,i=new Array(a);i[0]=d;var o={};for(var c in t)hasOwnProperty.call(t,c)&&(o[c]=t[c]);o.originalType=e,o.mdxType="string"==typeof e?e:n,i[1]=o;for(var s=2;s<a;s++)i[s]=r[s];return l.a.createElement.apply(null,i)}return l.a.createElement.apply(null,r)}d.displayName="MDXCreateElement"},96:function(e,t,r){"use strict";r.r(t),r.d(t,"frontMatter",(function(){return i})),r.d(t,"metadata",(function(){return o})),r.d(t,"toc",(function(){return c})),r.d(t,"default",(function(){return u}));var n=r(3),l=r(7),a=(r(0),r(132)),i={},o={unversionedId:"RealmSwiftAPI/classes/MultiRealmResultsController",id:"RealmSwiftAPI/classes/MultiRealmResultsController",isDocsHomePage:!1,title:"MultiRealmResultsController",description:"CLASS",source:"@site/docs/RealmSwiftAPI/classes/MultiRealmResultsController.md",slug:"/RealmSwiftAPI/classes/MultiRealmResultsController",permalink:"/SyncKit/RealmSwiftAPI/classes/MultiRealmResultsController",editUrl:"https://github.com/facebook/docusaurus/edit/master/website/docs/RealmSwiftAPI/classes/MultiRealmResultsController.md",version:"current",sidebar:"api",previous:{title:"DefaultRealmProvider",permalink:"/SyncKit/RealmSwiftAPI/classes/DefaultRealmProvider"},next:{title:"MultiRealmObserver",permalink:"/SyncKit/RealmSwiftAPI/classes/MultiRealmObserver"}},c=[{value:"Properties",id:"properties",children:[{value:"<code>results</code>",id:"results",children:[]},{value:"<code>didChangeRealms</code>",id:"didchangerealms",children:[]}]},{value:"Methods",id:"methods",children:[{value:"<code>deinit</code>",id:"deinit",children:[]},{value:"<code>observe(on:_:)</code>",id:"observeon_",children:[]}]}],s={toc:c};function u(e){var t=e.components,r=Object(l.a)(e,["components"]);return Object(a.b)("wrapper",Object(n.a)({},s,r,{components:t,mdxType:"MDXLayout"}),Object(a.b)("p",null,Object(a.b)("strong",{parentName:"p"},"CLASS")),Object(a.b)("h1",{id:"multirealmresultscontroller"},Object(a.b)("inlineCode",{parentName:"h1"},"MultiRealmResultsController")),Object(a.b)("pre",null,Object(a.b)("code",{parentName:"pre",className:"language-swift"},"public class MultiRealmResultsController<T: Object>\n")),Object(a.b)("h2",{id:"properties"},"Properties"),Object(a.b)("h3",{id:"results"},Object(a.b)("inlineCode",{parentName:"h3"},"results")),Object(a.b)("pre",null,Object(a.b)("code",{parentName:"pre",className:"language-swift"},"public private(set) var results: [Results<T>]\n")),Object(a.b)("h3",{id:"didchangerealms"},Object(a.b)("inlineCode",{parentName:"h3"},"didChangeRealms")),Object(a.b)("pre",null,Object(a.b)("code",{parentName:"pre",className:"language-swift"},"public var didChangeRealms: ((MultiRealmResultsController<T>)->())?\n")),Object(a.b)("h2",{id:"methods"},"Methods"),Object(a.b)("h3",{id:"deinit"},Object(a.b)("inlineCode",{parentName:"h3"},"deinit")),Object(a.b)("pre",null,Object(a.b)("code",{parentName:"pre",className:"language-swift"},"deinit\n")),Object(a.b)("h3",{id:"observeon_"},Object(a.b)("inlineCode",{parentName:"h3"},"observe(on:_:)")),Object(a.b)("pre",null,Object(a.b)("code",{parentName:"pre",className:"language-swift"},"public func observe(on queue: DispatchQueue? = nil, _ block: @escaping (MultiRealmCollectionChange) -> Void) -> MultiRealmObserver\n")))}u.isMDXComponent=!0}}]);