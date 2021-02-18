import Router02ABI from './uniscam-router02.json'
import { Interface } from 'ethers/lib/utils'

const Router02Interface = new Interface(Router02ABI)

export { Router02ABI, Router02Interface }
