// SPDX-FileCopyrightText: © 2024 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
pragma solidity ^0.8.16;

import {DssEmergencySpell} from "../DssEmergencySpell.sol";

interface IlkRegistryLike {
    function list() external view returns (bytes32[] memory);
    function xlip(bytes32 ilk) external view returns (address);
}

interface ClipperMomLike {
    function setBreaker(address clip, uint256 level, uint256 delay) external;
}

interface WardsLike {
    function wards(address who) external view returns (uint256);
}

contract UniversalClipBreakerSpell is DssEmergencySpell {
    IlkRegistryLike public immutable ilkReg = IlkRegistryLike(_log.getAddress("ILK_REGISTRY"));
    ClipperMomLike public immutable clipperMom = ClipperMomLike(_log.getAddress("CLIPPER_MOM"));

    string public constant override description = "Emergency Spell | Universal Clip Breaker";

    uint256 public constant BREAKER_LEVEL = 3;
    // For level 3 breakers, the delay is not applicable, so we set it to zero.
    uint256 public constant BREAKER_DELAY = 0;

    event SetBreaker(bytes32 indexed ilk, address indexed clip);

    constructor()
        // In practice, this spell would never expire
        DssEmergencySpell(type(uint256).max)
    {}

    function _onSchedule() internal override {
        bytes32[] memory ilks = ilkReg.list();
        for (uint256 i = 0; i < ilks.length; i++) {
            bytes32 ilk = ilks[i];
            address clip = ilkReg.xlip(ilk);

            if (clip == address(0)) continue;
            // Ignore Clip instances that have not relied on ClipperMom.
            if (WardsLike(clip).wards(address(clipperMom)) == 0) continue;

            try clipperMom.setBreaker(clip, BREAKER_LEVEL, BREAKER_DELAY) {
                emit SetBreaker(ilk, clip);
            } catch Error(string memory reason) {
                // Ignore any failing calls to `clipeprMom.setBreaker` with no revert reason.
                require(bytes(reason).length == 0, reason);
            }
        }
    }
}