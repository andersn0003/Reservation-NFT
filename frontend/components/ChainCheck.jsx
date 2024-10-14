// components/ChainCheck.js
import { useMoralis } from "react-moralis"
import { networkMapping } from "../constants"

const supportedChains = Object.keys(networkMapping)

export const ChainCheck = ({ children }) => {
    const { isWeb3Enabled, chainId } = useMoralis()

    if (!isWeb3Enabled) {
        return (
            <div className="text-red-600 font-bold">
                Please connect to Polygon Mumbai through a supported browser wallet.
            </div>
        )
    }

    // Render

    if (supportedChains.includes(parseInt(chainId).toString())) {
        return (
            <div className="flex flex-row items-center justify-center bg-green-200 text-green-800 p-2 rounded-lg shadow-sm">
                <svg
                    xmlns="http://www.w3.org/2000/svg"
                    className="h-6 w-6 mr-2"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                >
                    <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M5 13l4 4L19 7"
                    />
                </svg>
                <span className="font-semibold">Nice friend!&nbsp;</span>You are connected to a
                supported chainId: {chainId}
            </div>
        )
    }

    return (
        <div className="text-red-600 font-bold">{`Please switch to a supported chainId. The supported Chain Ids are: ${supportedChains}`}</div>
    )
}
