(window.webpackJsonp=window.webpackJsonp||[]).push([[15],{132:function(e,n,r){"use strict";r.d(n,"a",(function(){return s})),r.d(n,"b",(function(){return m}));var t=r(0),o=r.n(t);function c(e,n,r){return n in e?Object.defineProperty(e,n,{value:r,enumerable:!0,configurable:!0,writable:!0}):e[n]=r,e}function a(e,n){var r=Object.keys(e);if(Object.getOwnPropertySymbols){var t=Object.getOwnPropertySymbols(e);n&&(t=t.filter((function(n){return Object.getOwnPropertyDescriptor(e,n).enumerable}))),r.push.apply(r,t)}return r}function i(e){for(var n=1;n<arguments.length;n++){var r=null!=arguments[n]?arguments[n]:{};n%2?a(Object(r),!0).forEach((function(n){c(e,n,r[n])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(r)):a(Object(r)).forEach((function(n){Object.defineProperty(e,n,Object.getOwnPropertyDescriptor(r,n))}))}return e}function l(e,n){if(null==e)return{};var r,t,o=function(e,n){if(null==e)return{};var r,t,o={},c=Object.keys(e);for(t=0;t<c.length;t++)r=c[t],n.indexOf(r)>=0||(o[r]=e[r]);return o}(e,n);if(Object.getOwnPropertySymbols){var c=Object.getOwnPropertySymbols(e);for(t=0;t<c.length;t++)r=c[t],n.indexOf(r)>=0||Object.prototype.propertyIsEnumerable.call(e,r)&&(o[r]=e[r])}return o}var d=o.a.createContext({}),u=function(e){var n=o.a.useContext(d),r=n;return e&&(r="function"==typeof e?e(n):i(i({},n),e)),r},s=function(e){var n=u(e.components);return o.a.createElement(d.Provider,{value:n},e.children)},b={inlineCode:"code",wrapper:function(e){var n=e.children;return o.a.createElement(o.a.Fragment,{},n)}},p=o.a.forwardRef((function(e,n){var r=e.components,t=e.mdxType,c=e.originalType,a=e.parentName,d=l(e,["components","mdxType","originalType","parentName"]),s=u(r),p=t,m=s["".concat(a,".").concat(p)]||s[p]||b[p]||c;return r?o.a.createElement(m,i(i({ref:n},d),{},{components:r})):o.a.createElement(m,i({ref:n},d))}));function m(e,n){var r=arguments,t=n&&n.mdxType;if("string"==typeof e||t){var c=r.length,a=new Array(c);a[0]=p;var i={};for(var l in n)hasOwnProperty.call(n,l)&&(i[l]=n[l]);i.originalType=e,i.mdxType="string"==typeof e?e:t,a[1]=i;for(var d=2;d<c;d++)a[d]=r[d];return o.a.createElement.apply(null,a)}return o.a.createElement.apply(null,r)}p.displayName="MDXCreateElement"},85:function(e,n,r){"use strict";r.r(n),r.d(n,"frontMatter",(function(){return a})),r.d(n,"metadata",(function(){return i})),r.d(n,"toc",(function(){return l})),r.d(n,"default",(function(){return u}));var t=r(3),o=r(7),c=(r(0),r(132)),a={},i={unversionedId:"RealmSwiftAPI/enums/CloudKitSynchronizer.SyncError",id:"RealmSwiftAPI/enums/CloudKitSynchronizer.SyncError",isDocsHomePage:!1,title:"CloudKitSynchronizer.SyncError",description:"ENUM",source:"@site/docs/RealmSwiftAPI/enums/CloudKitSynchronizer.SyncError.md",slug:"/RealmSwiftAPI/enums/CloudKitSynchronizer.SyncError",permalink:"/SyncKit/RealmSwiftAPI/enums/CloudKitSynchronizer.SyncError",editUrl:"https://github.com/facebook/docusaurus/edit/master/website/docs/RealmSwiftAPI/enums/CloudKitSynchronizer.SyncError.md",version:"current"},l=[{value:"Cases",id:"cases",children:[{value:"<code>alreadySyncing</code>",id:"alreadysyncing",children:[]},{value:"<code>higherModelVersionFound</code>",id:"highermodelversionfound",children:[]},{value:"<code>recordNotFound</code>",id:"recordnotfound",children:[]},{value:"<code>cancelled</code>",id:"cancelled",children:[]}]}],d={toc:l};function u(e){var n=e.components,r=Object(o.a)(e,["components"]);return Object(c.b)("wrapper",Object(t.a)({},d,r,{components:n,mdxType:"MDXLayout"}),Object(c.b)("p",null,Object(c.b)("strong",{parentName:"p"},"ENUM")),Object(c.b)("h1",{id:"cloudkitsynchronizersyncerror"},Object(c.b)("inlineCode",{parentName:"h1"},"CloudKitSynchronizer.SyncError")),Object(c.b)("pre",null,Object(c.b)("code",{parentName:"pre",className:"language-swift"},"@objc public enum SyncError: Int, Error\n")),Object(c.b)("p",null,"SyncError"),Object(c.b)("h2",{id:"cases"},"Cases"),Object(c.b)("h3",{id:"alreadysyncing"},Object(c.b)("inlineCode",{parentName:"h3"},"alreadySyncing")),Object(c.b)("pre",null,Object(c.b)("code",{parentName:"pre",className:"language-swift"},"case alreadySyncing = 0\n")),Object(c.b)("p",null,"Received when synchronize is called while there was an ongoing synchronization."),Object(c.b)("h3",{id:"highermodelversionfound"},Object(c.b)("inlineCode",{parentName:"h3"},"higherModelVersionFound")),Object(c.b)("pre",null,Object(c.b)("code",{parentName:"pre",className:"language-swift"},"case higherModelVersionFound = 1\n")),Object(c.b)("p",null,"A synchronizer with a higer ",Object(c.b)("inlineCode",{parentName:"p"},"compatibilityVersion")," value uploaded changes to CloudKit, so those changes won't be imported here.\nThis error can be detected to prompt the user to update the app to a newer version."),Object(c.b)("h3",{id:"recordnotfound"},Object(c.b)("inlineCode",{parentName:"h3"},"recordNotFound")),Object(c.b)("pre",null,Object(c.b)("code",{parentName:"pre",className:"language-swift"},"case recordNotFound = 2\n")),Object(c.b)("p",null,"A record fot the provided object was not found, so the object cannot be shared on CloudKit."),Object(c.b)("h3",{id:"cancelled"},Object(c.b)("inlineCode",{parentName:"h3"},"cancelled")),Object(c.b)("pre",null,Object(c.b)("code",{parentName:"pre",className:"language-swift"},"case cancelled = 3\n")),Object(c.b)("p",null,"Synchronization was manually cancelled."))}u.isMDXComponent=!0}}]);