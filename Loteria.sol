// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract loteria is ERC20, Ownable {

    //==============================
    //Gestion de tokens
    //==============================

    //Direccion NFT del proyecto
    address public nft;

    constructor() ERC20("Beans", "BE"){
        _mint(address(this), 400000);
        nft = address(new mainERC721());
    }

    //Ganador de la loteria, voy a hacerlo privado
    address public ganador;

    //Rgistro de usarios
    mapping (address => address) public usuario_contract;//relaciona el usuario con su samrt contract propio

    //precio de los tokens
    function precioTokens (uint256 _numTokens) internal pure returns (uint256){
        return _numTokens * (0.003 ether);
    }

    //Visualizacion del balance de erc20 de un usuario
    function BalanceTokens(address _account) public view returns (uint256){
        return balanceOf(_account);
    }
    //Visualizacion del balance de erc20 del smart contract
    function BalanceTokensSC() public view returns (uint256){
        return balanceOf(address(this));
    }

    //Visualizacion de ethres del contrato
    function balanceEthersSC() public view returns (uint256){
        return address(this).balance / 10**18;// 10**18 es lo que hay que dividir a los gwei para obtener ethers
    }

    //Generacion de nuevos tokens erc20
    function Mint(uint256 _cantidad) public onlyOwner {
        _mint(address(this), _cantidad);
    }

    //Registro de usuaruios
    function Registrar() internal {
        address addr_personal_contract = address(new BoletosNFTs(msg.sender, address(this), nft));
        usuario_contract[msg.sender] = addr_personal_contract;
    }

    //Indofrmacion de un usuario
    function usersInfo(address _account) public view returns (address){
        return usuario_contract[_account];
    }

    //Compra de tokens ERC20
    function compraTokens(uint256 _numTokens) public payable{ 
        //registro usuario
        if (usuario_contract[msg.sender] == address(0)) {
            Registrar();
        }
        //establecer el costo
        uint256 costo = precioTokens(_numTokens);
        //evaluacion del dinero que el cliente quiera pagar
        require(msg.value >= costo, "Saldo insuficiente");
        //Obtencion del numero de tokens disponibles
        uint256 balance = BalanceTokensSC();
        require(_numTokens <= balance, "no hay suficientes monedas disponibles");
        //Devolucion del excedente de eth
        uint256 returnValue = msg.value - costo;
        //El SC devuelve el excedente
        payable (msg.sender).transfer(returnValue);
        //Envio de los tokens al cliente
        _transfer(address(this), msg.sender, _numTokens);
    }

    //Devolucion de tokens
    function devolverTokens(uint256 _numTokens) public payable {
        //el numero de tokens debe ser mayor a cero
        require(_numTokens > 0, "El numero de tokens debe ser mayor a 0");
        //El usuario debe tener posesion de los tokens que quire devolver
        require(_numTokens <= BalanceTokens(msg.sender), "No tienes esa cantidad de tokens");
        //Transferrencia del usuario al SC
        _transfer(msg.sender, address(this), _numTokens);
        //Transferencia del SC al usuario
        payable(msg.sender).transfer(precioTokens(_numTokens));

    }

    //==============================
    //Gestion de la loteria
    //==============================

    //Precio del boleto de la loteria(en tokens ERC20)
    uint public precioBoleto = 2;
    //Relacion comprador - boletos
    mapping(address => uint [] ) idPersona_boletos;
    //Relacion boleto-ganador
    mapping(uint => address) ADNBoleto;
    //Numero aleatorio
    uint randNonce = 0;
    //Boletos de loteria generados
    uint [] boletosComprados;


    //Compra de boletos de loteria
    function compraBoletos (uint _numBoletos) public {
        //Precio total de los boletos a comprar
        uint precioTotal = _numBoletos*precioBoleto;
        //verificaion tokens del usuario
        require(precioTotal <= BalanceTokens(msg.sender), "No tienes tokens suficientes");
        //Transferencia de tokens del usuario al SC
        _transfer(msg.sender, address(this), precioTotal);

        /*Generacion de un numero random mediante un hash con entradas de timestamp, direccion y numero que 
        sube cada vez que se activa. limitada a numeros de 0 a 9999 con el modulo(%) de 10000, cosa que se puede cambiar */
        for (uint i = 0; i < _numBoletos; i++){
            uint random = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))) % 1000000;
            randNonce++;
            //Almacenamiento de los datos de los boletos enlazados con los usuarios
            idPersona_boletos[msg.sender].push(random);
            //Almacenamiento de los datos de los boletos
            boletosComprados.push(random);
            //Asignacion del ADN del boleto para la generacion de un ganador
            ADNBoleto[random] = msg.sender;
            //Creacion de un nuevo NFT para cada boleto
            BoletosNFTs(usuario_contract[msg.sender]).mintBoleto(msg.sender, random);
        }
    }

    //visualizacion de los boletos del usuario
    function tusBoletos (address _propietario) public view returns (uint [] memory){
        return idPersona_boletos[_propietario];
    }

    //Generacion del ganador de la loteria
    function generarGanador() public onlyOwner {
        //Declaracion de longitud del array
        uint longitud = boletosComprados.length;
        //verificacion de la compra de mas de un boletos
        require(longitud > 0, "No se han comprado suficientes boletos");

        //Eleccion aleatoria de un numero de 0 a "longitud"
        uint random = uint(uint(keccak256(abi.encodePacked(block.timestamp))) % longitud);
        //Seleccion del numero aleatorio
        uint eleccion = boletosComprados[random];
        //Direccion del ganador
        ganador = ADNBoleto[eleccion];
        //Envio del 90% del premio de loteria al ganador
        payable(ganador).transfer(address(this).balance * 90 / 100);
        //Envio de la ganancia del 10% restante al owner
        payable(owner()).transfer(address(this).balance);
    }


}

//smart contract de NFTs
contract mainERC721 is ERC721 {

    address public direccionLoteria;

    constructor() ERC721("Loteria", "BOL"){
        direccionLoteria = msg.sender;
    }

    //funcion de creacion de NFTs
    function safeMint(address _propietario, uint256 _boleto) public{
        require(msg.sender == loteria(direccionLoteria).usersInfo(_propietario), "no tienes permiso para ejecutar esta funcion");
        _safeMint(_propietario, _boleto);
    }
}

contract BoletosNFTs {

    //Datos del propietario
    struct Owner {
        address direccionPropietario;
        address contratoPadre;
        address contratoNFT;
        address contratoUsuario;
    }

    //estructura tipo owner
    Owner public propietario;

    //Constructor del smarrrt contract (hijo)
    constructor (address _propietario, address _contratoPadre, address _contratoNFT){//se pueden anadir variables
        propietario = Owner(_propietario, _contratoPadre, _contratoNFT, address(this));
    }

    //conversion numeros de loteria a NFT

    function mintBoleto(address _propietario, uint256 _boleto) public {
        require(msg.sender == propietario.contratoPadre, "No tienes permiso para ejecutar esta funcion");
        mainERC721(propietario.contratoNFT).safeMint(_propietario, _boleto);
    }

}