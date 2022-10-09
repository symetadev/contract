pragma solidity ^0.8.13;
import "./IERC20.sol";
import "./Ownable.sol";
import "./EnumerableSet.sol";

contract Symeta is Ownable{
    using EnumerableSet for EnumerableSet.AddressSet;
    struct Subscription{
        address merchant;
        address user;
        uint256 recurring;
        address currency;
        uint256 amount;
        string  sku;
        uint256 lastTimeTrigger;
        uint256 subscribeTime;
    }
    //
    mapping(address=>bool) public workers;
    mapping(address=>bool) public currencies;
    mapping(address=>bool) public merchants;
    mapping(address=>mapping(address=>Subscription)) public subscription;//user=>merchant=>struct
    mapping(address=>EnumerableSet.AddressSet) private userActive; //users=>active merchant address
    mapping(address=>EnumerableSet.AddressSet) private merchantActive; //merchant=>active users address
    //

    //
    event SetMerchant(address indexed _merchant,bool indexed _active);
    event SetWorker(address indexed _worker,bool indexed _active);
    event SetCurrency(address indexed _currency,bool indexed _active);
    event Subscribe(address indexed _user, address indexed _merchant,uint256 _recurring, address _currency, uint256 _amount,string indexed _sku);
    event UnSubscribe(address indexed _user, address indexed _merchant);
    //
    //status=1 is success,status=2 is insufficient balance,status=3 is have enough balance but insufficient allowance
    event TriggerSubscription(address indexed _user,address indexed _merchant,string indexed _sku,address _currency,uint256 _amount, uint256 _status);
    //
    event Pay(address indexed _user, address indexed _merchant,address _currency, uint256 _amount, string indexed _sku);
    //
    modifier OnlyWorker(){
        require(workers[_msgSender()],"you're not allowed to trigger");
        _;
    }
    function setMerchant(address _merchant,bool _active) public onlyOwner {
        require(merchants[_merchant]!=_active,"merchant is already set as you want");
        merchants[_merchant] = _active;
        emit SetMerchant(_merchant,_active);
    }
    function setCurrency(address _currency,bool _active) public onlyOwner {
        require(currencies[_currency]!=_active,"currency is already set as you want");
        currencies[_currency] = _active;
        emit SetCurrency(_currency,_active);
    }
    function setWorker(address _worker,bool _active) public onlyOwner {
        require(workers[_worker]!=_active,"worker is already set as you want");
        workers[_worker] = _active;
        emit SetWorker(_worker,_active);
    }
    function subscribe(address _merchant, uint256 _recurring,address _currency, uint256 _amount, string calldata _sku ) public {
        require(!userActive[_msgSender()].contains(_merchant) && !merchantActive[_merchant].contains(_msgSender()),"merchant is already subscribe" );
        require(currencies[_currency],"currency is not allowed");
        subscription[_msgSender()][_merchant]=Subscription({merchant:_merchant,user:_msgSender(),recurring:_recurring,currency:_currency,amount:_amount,sku:_sku,lastTimeTrigger:0,subscribeTime:block.timestamp});
        userActive[_msgSender()].add(_merchant);
        merchantActive[_merchant].add(_msgSender());
        emit Subscribe(_msgSender(),_merchant,_recurring,_currency,_amount,_sku);
    }

    function unsubscribe(address _merchant) public {
        require(userActive[_msgSender()].contains(_merchant) && merchantActive[_merchant].contains(_msgSender()),"merchant is already unsubscribe" );
        delete subscription[_msgSender()][_merchant];
        userActive[_msgSender()].remove(_merchant);
        merchantActive[_merchant].remove(_msgSender());
        emit UnSubscribe(_msgSender(),_merchant);
    }

    function triggerSubscription(address _merchant, address _user) public OnlyWorker {
        require(userActive[_user].contains(_merchant) && merchantActive[_merchant].contains(_user),"merchant is already unsubscribe" );
        Subscription storage _sub = subscription[_user][_merchant];
        require(_sub.lastTimeTrigger+_sub.recurring < block.timestamp,"It's not time for trigger");

        if(IERC20(_sub.currency).balanceOf(_sub.user)<_sub.amount){
            emit TriggerSubscription(_sub.user,_sub.merchant,_sub.sku, _sub.currency, _sub.amount, 2);
        } else if(IERC20(_sub.currency).allowance(_sub.user,_sub.merchant)<_sub.amount){
            emit TriggerSubscription(_sub.user,_sub.merchant,_sub.sku, _sub.currency, _sub.amount, 3);
        } else{
            IERC20(_sub.currency).transferFrom(_sub.user,_sub.merchant,_sub.amount);
            _sub.lastTimeTrigger = block.timestamp;
            emit TriggerSubscription(_sub.user,_sub.merchant,_sub.sku, _sub.currency, _sub.amount, 1);
        }
        
    }

    function getActiveSubscriptionByUser(address _user) public view returns(address[] memory)  {
        return userActive[_user].values();
    }

    function getActiveSubscriptionByMerchain(address _merchant) public view returns(address[] memory) {
        return merchantActive[_merchant].values();
    }

    function pay(address _merchant,address _currency, uint256 _amount,string calldata _sku) public {
        require(currencies[_currency],"currency is not allowed");
        require(merchants[_merchant],"merchant is not registered");
        IERC20(_currency).transferFrom(_msgSender(),_merchant,_amount);
        emit Pay(_msgSender(), _merchant,_currency, _amount,  _sku);
    }
}