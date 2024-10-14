import React, { useEffect } from "react"
import { useMoralis } from "react-moralis"
import { useQuery } from "@apollo/client"
import { Loading } from "web3uikit"
import subgraphQueries from "@/constants/subgraphQueries"
import { RestaurantsTable } from "@/components/RestaurantsTable"

const { GET_ACTIVE_RESTAURANTS } = subgraphQueries

export default function ActiveRestaurants({ updateKey }) {
    const { Moralis, chainId, isWeb3Enabled, account } = useMoralis()

    // Queries

    const {
        loading,
        error,
        data: activeRestaurants,
        refetch,
    } = useQuery(GET_ACTIVE_RESTAURANTS, {
        skip: !isWeb3Enabled || !account,
    })

    useEffect(() => {
        refetch()
    }, [updateKey])

    if (loading) {
        return (
            <div
                style={{
                    backgroundColor: "white",
                    borderRadius: "8px",
                    padding: "20px",
                }}
            >
                <Loading />
            </div>
        )
    }
    if (error) return <div>Error: {error.message}</div>
    if (!activeRestaurants?.restaurants?.length) return null

    const data = activeRestaurants.restaurants.map((restaurant) => {
        return {
            ...restaurant,
        }
    })

    // Render

    return (
        <div className="p-5">
            <h1 className="pb-4 font-bold text-3xl">Active Restaurants</h1>
            <RestaurantsTable
                data={data}
                columnsConfig="4fr 8fr 2fr"
                header={[<span>Name</span>, <span>Address</span>]}
                showStatus={false}
            />
        </div>
    )
}
